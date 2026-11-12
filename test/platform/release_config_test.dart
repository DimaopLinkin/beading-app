import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Проверяет конфигурацию подписи и разрешений (T10). Нативную сборку в CI не гоняем,
/// поэтому ловим опечатки и забытые ключи здесь.
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// Значение `<key>name</key><string>value</string>` из plist.
  String? stringValue(String plist, String key) =>
      RegExp('<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>').firstMatch(plist)?.group(1);

  bool hasTrue(String plist, String key) => RegExp('<key>${RegExp.escape(key)}</key>\\s*<true/>').hasMatch(plist);

  final RegExp cyrillic = RegExp('[А-Яа-яЁё]');

  group('Info.plist: тексты разрешений по-русски', () {
    for (final String platform in <String>['ios', 'macos']) {
      final String plist = read('$platform/Runner/Info.plist');

      for (final String key in <String>['NSCameraUsageDescription', 'NSPhotoLibraryUsageDescription']) {
        test('$platform: $key', () {
          final String? text = stringValue(plist, key);
          expect(text, isNotNull, reason: '$key нужен для камеры и фото');
          expect(text, matches(cyrillic));
          expect(text!.length, greaterThan(20));
        });
      }

      test('$platform: имя под значком — «Канитель»', () {
        expect(stringValue(plist, 'CFBundleDisplayName'), 'Канитель');
      });
    }

    test('ios: шифрование без экспортных ограничений объявлено', () {
      expect(read('ios/Runner/Info.plist'), contains('ITSAppUsesNonExemptEncryption'));
    });

    test('macos: категория приложения задана', () {
      expect(
        stringValue(read('macos/Runner/Info.plist'), 'LSApplicationCategoryType'),
        startsWith('public.app-category.'),
      );
    });
  });

  group('тип файла .biser (T21)', () {
    for (final String platform in <String>['ios', 'macos']) {
      final String plist = read('$platform/Runner/Info.plist');
      test('$platform: тип объявлен и приложение — его владелец', () {
        expect(plist, contains('UTExportedTypeDeclarations'));
        expect(plist, contains('CFBundleDocumentTypes'));
        expect(plist, contains('<string>biser</string>'));
        expect('com.dimaoplinkin.beading.biser'.allMatches(plist), hasLength(2));
        expect(stringValue(plist, 'LSHandlerRank'), 'Owner');
      });
    }

    test('ios: файл копируется в приложение, а не открывается на месте', () {
      expect(
        RegExp(r'<key>LSSupportsOpeningDocumentsInPlace</key>\s*<false/>').hasMatch(read('ios/Runner/Info.plist')),
        isTrue,
      );
    });

    test('macos: нативный AppDelegate передаёт пути каналом app.beading/incoming_files', () {
      expect(read('macos/Runner/AppDelegate.swift'), contains('app.beading/incoming_files'));
      expect(read('macos/Runner/MainFlutterWindow.swift'), contains('incomingFiles.attach'));
    });
  });

  group('macOS entitlements', () {
    final String release = read('macos/Runner/Release.entitlements');
    final String debug = read('macos/Runner/DebugProfile.entitlements');

    for (final MapEntry<String, String> file in <String, String>{'Release': release, 'DebugProfile': debug}.entries) {
      for (final String key in <String>[
        'com.apple.security.app-sandbox',
        'com.apple.security.files.user-selected.read-write',
        'com.apple.security.device.camera',
        'com.apple.security.personal-information.photos-library',
      ]) {
        test('${file.key}: $key', () => expect(hasTrue(file.value, key), isTrue));
      }
    }

    test('Release без JIT и серверных прав', () {
      expect(release, isNot(contains('allow-jit')));
      expect(release, isNot(contains('network.server')));
    });

    test('в Release включён Hardened Runtime (нужен для нотаризации)', () {
      expect(read('macos/Runner.xcodeproj/project.pbxproj'), contains('ENABLE_HARDENED_RUNTIME = YES'));
    });
  });

  group('ExportOptions', () {
    test('ios Ad Hoc', () {
      final String plist = read('ios/ExportOptions-AdHoc.plist');
      expect(stringValue(plist, 'method'), 'ad-hoc');
      expect(plist, contains('__TEAM_ID__'));
      expect(stringValue(plist, 'signingStyle'), 'automatic');
      expect(hasTrue(plist, 'compileBitcode'), isFalse);
    });

    test('macos Developer ID', () {
      final String plist = read('macos/ExportOptions-DeveloperID.plist');
      expect(stringValue(plist, 'method'), 'developer-id');
      expect(plist, contains('__TEAM_ID__'));
      expect(stringValue(plist, 'signingStyle'), 'automatic');
    });
  });

  group('иконки-заглушки', () {
    test('iOS: 1024×1024 без прозрачности по всем размерам из Contents.json есть файлы', () {
      final String contents = read('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json');
      final Iterable<RegExpMatch> files = RegExp(r'"filename"\s*:\s*"([^"]+)"').allMatches(contents);
      expect(files, isNotEmpty);
      for (final RegExpMatch file in files) {
        expect(File('ios/Runner/Assets.xcassets/AppIcon.appiconset/${file.group(1)}').existsSync(), isTrue);
      }
    });

    const List<String> iosIcons = <String>[
      'AppIcon-1024.png',
      'AppIcon-1024-dark.png',
      'AppIcon-1024-tinted.png',
    ];

    test('значок настоящий (из UI kit), а не заглушка', () {
      for (final String name in iosIcons) {
        final List<int> bytes = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/$name').readAsBytesSync();
        // Заглушку рисовал удалённый скрипт и помечал tEXt-блоком; настоящая иконка «Канитель» принята в 13-app-icon.
        expect(String.fromCharCodes(bytes), isNot(contains('beading-placeholder')), reason: name);
      }
    });

    test('значки iOS 1024 (светлый, тёмный, tinted) без альфа-канала (требование App Store и Ad Hoc)', () {
      for (final String name in iosIcons) {
        final List<int> bytes = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/$name').readAsBytesSync();
        // PNG: 8 байт подписи, 8 байт заголовка IHDR, затем ширина, высота, глубина (1) и тип цвета (1): 2 = RGB без альфы.
        expect(bytes[25], 2, reason: name);
      }
    });
  });
}
