import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Запускает scripts/check_architecture.sh на временной фикстуре проекта.
void main() {
  late Directory fixture;
  final String script = '${Directory.current.path}/scripts/check_architecture.sh';

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('arch_fixture_');
    File('${fixture.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
  });

  tearDown(() => fixture.deleteSync(recursive: true));

  void write(String path, String content) {
    File('${fixture.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  ProcessResult run() => Process.runSync('bash', <String>[script, fixture.path]);

  test('чистый проект проходит', () {
    write('lib/domain/a.dart', "import 'dart:math';\n");
    write('lib/data/b.dart', "import 'package:demo/domain/a.dart';\n");
    write('lib/presentation/c.dart', "import 'package:flutter/material.dart';\nimport 'package:demo/domain/a.dart';\n");

    expect(run().exitCode, 0);
  });

  test('пустой проект без слоёв проходит', () {
    expect(run().exitCode, 0);
  });

  const Map<String, String> violations = <String, String>{
    'lib/domain/a.dart': "import 'package:flutter/material.dart';",
    'lib/domain/b.dart': "import 'package:demo/data/x.dart';",
    'lib/domain/c.dart': "import 'dart:io';",
    'lib/domain/d.dart': "export 'package:drift/drift.dart';",
    'lib/core/e.dart': "import 'package:demo/domain/x.dart';",
    'lib/data/f.dart': "import 'package:demo/presentation/x.dart';",
    'lib/presentation/g.dart': "import 'package:demo/data/x.dart';",
    'lib/presentation/h.dart': "import 'package:drift/drift.dart';",
  };

  violations.forEach((path, line) {
    test('ловит запрещённый импорт: $path', () {
      write(path, '$line\n');

      final ProcessResult result = run();

      expect(result.exitCode, 1);
      expect(result.stdout, contains('ARCH:'));
      expect(result.stdout, contains(path));
    });
  });
}
