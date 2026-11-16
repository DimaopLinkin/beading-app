import 'dart:io';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/data/steps/asset_step_template_source.dart';
import 'package:beading/domain/steps/step_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('встроенные шаблоны', () {
    test('каждый файл assets/step_templates проходит кодек, шаги не пустые, id уникальны', () async {
      final List<File> files = Directory(
        'assets/step_templates',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList();
      expect(files, isNotEmpty);
      final Set<String> ids = <String>{};
      for (final File f in files) {
        final StepTemplate t = await AssetStepTemplateSource.parse(f.readAsStringSync(), (file) async {
          return File('assets/step_templates/$file').readAsBytesSync();
        });
        expect(ids.add(t.id), isTrue, reason: 'повторный id ${t.id}');
        expect(t.title, isNotEmpty);
        expect(t.sections.expand((s) => s.steps), isNotEmpty);
        for (final image in t.images) {
          expect(image.png, isNotEmpty);
        }
      }
    });

    test('источник на ассетах отдаёт список и шаблон по id; неизвестный id — NotFound', () async {
      final AssetStepTemplateSource source = AssetStepTemplateSource();
      final List<StepTemplate> all = (await source.all()).valueOrNull!;
      expect(all, isNotEmpty);
      expect((await source.get(all.first.id)).isSuccess, isTrue);
      expect((await source.get('нет-такого')).failureOrNull, isA<NotFoundFailure>());
    });

    test('картинка шаблона читается через переданный загрузчик, битый документ бросает', () async {
      const String json =
          '{"id":"t","title":"T","body":{"v":1,"palette":[],"sections":[{"id":"s","title":"","repeat":1,"steps":[{"id":"a","text":"x","images":["i"],"beads":[],"repeat":1}]}]},'
          '"images":[{"id":"i","file":"t-i.png","width":3,"height":4}]}';
      final StepTemplate t = await AssetStepTemplateSource.parse(
        json,
        (file) async => Uint8List.fromList(<int>[file.length]),
      );
      expect(t.images.single.png, <int>[7]);
      expect(t.images.single.width, 3);
      await expectLater(
        AssetStepTemplateSource.parse('{"id":"b","title":"B","body":{"v":99}}', (_) async => Uint8List(0)),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
