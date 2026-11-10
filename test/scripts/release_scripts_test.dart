import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Гоняет scripts/release_ios.sh и release_macos.sh с подставными flutter, xcodebuild, xcrun и т. п.:
/// проверяем порядок и аргументы команд, не имея Mac.
void main() {
  late Directory work;
  late Directory stubs;
  late File log;
  final String root = Directory.current.path;

  setUp(() {
    work = Directory.systemTemp.createTempSync('release_work_');
    stubs = Directory('${work.path}/stubs')..createSync();
    log = File('${work.path}/calls.log')..createSync();
    // Копия скриптов и шаблонов в «проект», чтобы cd "$(dirname "$0")/.." попал в песочницу.
    for (final String f in <String>[
      'scripts/release_common.sh',
      'scripts/release_ios.sh',
      'scripts/release_macos.sh',
      'ios/ExportOptions-AdHoc.plist',
      'macos/ExportOptions-DeveloperID.plist',
    ]) {
      File('${work.path}/proj/$f')
        ..createSync(recursive: true)
        ..writeAsStringSync(File('$root/$f').readAsStringSync());
    }
    File('${work.path}/proj/pubspec.yaml').writeAsStringSync('name: beading\nversion: 0.1.0+7\n');

    void stub(String name, String body) {
      final File f = File('${stubs.path}/$name')..writeAsStringSync('#!/usr/bin/env bash\n$body\n');
      Process.runSync('chmod', <String>['+x', f.path]);
    }

    const String record = r'echo "$(basename "$0") $*" >> "$CALLS_LOG"';
    for (final String name in <String>['flutter', 'codesign', 'ditto', 'hdiutil', 'spctl', 'ln']) {
      stub(name, record);
    }
    stub('xcrun', record);
    stub('uname', 'echo Darwin');
    stub('git', r'''
case "$1" in
  status) echo "$STUB_GIT_DIRTY" ;;
  describe) [ -n "$STUB_GIT_TAG" ] && echo "$STUB_GIT_TAG" || exit 128 ;;
esac''');
    stub('xcodebuild', '''
$record
while [ \$# -gt 0 ]; do
  [ "\$1" = "-exportPath" ] && { mkdir -p "\$2"; touch "\$2/beading.ipa"; mkdir -p "\$2/beading.app"; }
  shift
done
exit 0''');
  });

  tearDown(() => work.deleteSync(recursive: true));

  ProcessResult run(String script, {Map<String, String> env = const <String, String>{}, List<String> args = const []}) {
    return Process.runSync(
      'bash',
      <String>['${work.path}/proj/scripts/$script', ...args],
      environment: <String, String>{
        'PATH': '${stubs.path}:${Platform.environment['PATH']}',
        'CALLS_LOG': log.path,
        'STUB_GIT_DIRTY': '',
        'STUB_GIT_TAG': 'v0.1.0',
        'TEAM_ID': 'ABCDE12345',
        ...env,
      },
      workingDirectory: '${work.path}/proj',
    );
  }

  List<String> calls() => log.readAsLinesSync();

  group('release_ios.sh', () {
    test('без TEAM_ID останавливается', () {
      final ProcessResult r = run('release_ios.sh', env: <String, String>{'TEAM_ID': ''});

      expect(r.exitCode, isNot(0));
      expect(r.stderr, contains('TEAM_ID'));
      expect(calls(), isEmpty);
    });

    test('не принимает странный TEAM_ID', () {
      expect(run('release_ios.sh', env: <String, String>{'TEAM_ID': 'abc'}).exitCode, isNot(0));
    });

    test('архив и экспорт Ad Hoc в правильном порядке, ipa получает версию', () {
      final ProcessResult r = run('release_ios.sh');

      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      final List<String> c = calls();
      expect(
        c[0],
        startsWith('flutter build ios --release --config-only --no-codesign --build-name 0.1.0 --build-number 7'),
      );
      expect(c[1], allOf(contains('xcodebuild'), contains('archive'), contains('DEVELOPMENT_TEAM=ABCDE12345')));
      expect(c[2], allOf(contains('-exportArchive'), contains('ExportOptions.plist')));
      expect(File('${work.path}/proj/build/release/biser-0.1.0+7-adhoc.ipa').existsSync(), isTrue);
      final String options = File('${work.path}/proj/build/release/ios/ExportOptions.plist').readAsStringSync();
      expect(options, contains('<string>ABCDE12345</string>'));
      expect(options, contains('<string>ad-hoc</string>'));
    });

    test('--install ставит ipa на устройство через devicectl', () {
      final ProcessResult r = run('release_ios.sh', args: <String>['--install', 'IPHONE-UDID']);

      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(
        calls().last,
        allOf(contains('devicectl device install app --device IPHONE-UDID'), endsWith('-adhoc.ipa')),
      );
    });

    test('без тега отказывается собирать', () {
      final ProcessResult r = run('release_ios.sh', env: <String, String>{'STUB_GIT_TAG': ''});

      expect(r.exitCode, isNot(0));
      expect(r.stderr, contains('без тега'));
      expect(calls(), isEmpty);
    });

    test('тег от другой версии отклоняется', () {
      expect(run('release_ios.sh', env: <String, String>{'STUB_GIT_TAG': 'v0.2.0'}).exitCode, isNot(0));
    });

    test('грязное дерево отклоняется', () {
      expect(run('release_ios.sh', env: <String, String>{'STUB_GIT_DIRTY': ' M lib/a.dart'}).exitCode, isNot(0));
    });

    test('ALLOW_UNTAGGED=1 — пробная сборка с -dev в имени', () {
      final ProcessResult r = run(
        'release_ios.sh',
        env: <String, String>{'STUB_GIT_TAG': '', 'ALLOW_UNTAGGED': '1', 'STUB_GIT_DIRTY': ' M x'},
      );

      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(File('${work.path}/proj/build/release/biser-0.1.0+7-adhoc-dev.ipa').existsSync(), isTrue);
    });

    test('BUILD_NUMBER из окружения важнее номера из pubspec', () {
      run('release_ios.sh', env: <String, String>{'BUILD_NUMBER': '12'});

      expect(calls().first, contains('--build-number 12'));
    });

    test('DRY_RUN только печатает команды', () {
      final ProcessResult r = run('release_ios.sh', env: <String, String>{'DRY_RUN': '1'});

      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(calls(), isEmpty);
      expect(r.stdout, contains('+ xcodebuild'));
    });

    test('на Linux без DRY_RUN сборка невозможна', () {
      File('${stubs.path}/uname').writeAsStringSync('#!/usr/bin/env bash\necho Linux\n');

      final ProcessResult r = run('release_ios.sh');

      expect(r.exitCode, isNot(0));
      expect(r.stderr, contains('Mac'));
    });
  });

  group('release_macos.sh', () {
    test('подпись, нотаризация app, staple, dmg, нотаризация dmg — по порядку', () {
      final ProcessResult r = run('release_macos.sh');

      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      final List<String> c = calls();
      int at(Pattern p) => c.indexWhere((l) => l.contains(p));
      expect(c.first, startsWith('flutter build macos --release --config-only'));
      expect(at('archive'), greaterThan(0));
      expect(at('-exportArchive'), greaterThan(at('archive')));
      expect(at('codesign --verify --deep --strict'), greaterThan(at('-exportArchive')));
      expect(
        at('notarytool submit build/release/macos/app.zip --keychain-profile biser-notary --wait'),
        greaterThan(at('codesign --verify')),
      );
      expect(at('stapler staple build/release/macos/export/beading.app'), greaterThan(at('app.zip')));
      expect(at('hdiutil create'), greaterThan(at('stapler staple build/release/macos/export')));
      expect(at('codesign --sign Developer ID Application --timestamp'), greaterThan(at('hdiutil')));
      expect(at('notarytool submit build/release/biser-0.1.0+7.dmg'), greaterThan(at('--sign')));
      expect(c.last, contains('spctl --assess --type open'));
      expect(c.where((l) => l.contains('stapler staple')).length, 2);
      expect(
        File('${work.path}/proj/build/release/macos/ExportOptions.plist').readAsStringSync(),
        contains('developer-id'),
      );
    });

    test('профиль нотаризации и сертификат настраиваются', () {
      run(
        'release_macos.sh',
        env: <String, String>{
          'NOTARY_PROFILE': 'mine',
          'DEVELOPER_ID_IDENTITY': 'Developer ID Application: X (ABCDE12345)',
        },
      );

      expect(calls().any((l) => l.contains('--keychain-profile mine')), isTrue);
      expect(calls().any((l) => l.contains('--sign Developer ID Application: X (ABCDE12345)')), isTrue);
    });

    test('без тега отказывается собирать', () {
      expect(run('release_macos.sh', env: <String, String>{'STUB_GIT_TAG': ''}).exitCode, isNot(0));
      expect(calls(), isEmpty);
    });

    test('ALLOW_UNTAGGED=1 даёт dmg с -dev', () {
      final ProcessResult r = run('release_macos.sh', env: <String, String>{'STUB_GIT_TAG': '', 'ALLOW_UNTAGGED': '1'});

      expect(r.stdout, contains('biser-0.1.0+7-dev.dmg'));
    });
  });
}
