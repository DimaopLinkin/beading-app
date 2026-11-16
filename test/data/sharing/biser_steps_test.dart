import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/sharing/zip_biser_codec.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/domain/steps/repeat.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/steps_progress.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/biser_device.dart';
import '../../support/test_images.dart';

/// Инструкции в `.biser` v5 (T33b): документ, картинки и курсор переезжают и в одном проекте, и в резервной копии.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List png;
  setUpAll(() async => png = await redBluePng());

  Future<StepPattern> seed(BiserDevice device, {String projectId = 'proj1'}) async {
    await device.projects.save(sampleProject(projectId, kind: ContentKind.steps, name: 'Жгут'));
    final StepPattern pattern = StepPattern(
      id: 'pattern1',
      projectId: projectId,
      palette: <PatternColor>[
        PatternColor(
          rgb: const Rgb(1, 2, 3),
          name: 'Синий',
          components: const <CatalogRef>[CatalogRef(brand: 'Miyuki', code: 'DB0010')],
        ),
      ],
      images: const <StepImage>[
        StepImage(id: 'img1', path: 'step_patterns/pattern1/img1.png', width: 1, height: 1),
      ],
      sections: const <StepSection>[
        StepSection(
          id: 'sec1',
          repeat: Repeat.times(3),
          steps: <InstructionStep>[
            InstructionStep(
              id: 'st1',
              text: 'Нанижи',
              imageIds: <String>['img1'],
              beads: <StepBead>[StepBead(colorIndex: 0, count: 4)],
              repeat: Repeat.untilDone(),
            ),
            InstructionStep(id: 'st2'),
          ],
        ),
      ],
    );
    await device.realFiles.write('step_patterns/pattern1/img1.png', png);
    await device.steps.save(pattern);
    await device.stepsProgress.save(
      pattern.id,
      const StepsProgress(sectionId: 'sec1', sectionPass: 2, stepId: 'st2', stepPass: 1),
    );
    return pattern;
  }

  test('резервная копия: инструкция с картинкой и курсором переезжает на пустое устройство, формат 5', () async {
    final BiserDevice a = BiserDevice();
    final BiserDevice b = BiserDevice();
    final StepPattern original = await seed(a);

    final Uint8List bytes = await a.backupBytes();
    expect(const ZipBiserCodec().decode(bytes).valueOrNull!.formatVersion, 5);
    expect((await b.import(bytes)).failureOrNull, isNull);

    final StepPattern restored = (await b.steps.getByProject('proj1')).valueOrNull!;
    expect(restored.id, original.id);
    expect(restored.sections, original.sections);
    expect(restored.palette, original.palette);
    expect(restored.images.single.id, 'img1');
    expect(await b.realFiles.read(restored.images.single.path), Success<Uint8List>(png));
    expect(
      (await b.stepsProgress.load(restored.id)).valueOrNull,
      const StepsProgress(sectionId: 'sec1', sectionPass: 2, stepId: 'st2', stepPass: 1),
    );
    expect((await b.allProjects()).single.coverPath, restored.images.single.path);
  });

  test('«как новый»: новые id инструкции и картинок, шаги ссылаются на новые картинки, исходное не тронуто', () async {
    final BiserDevice a = BiserDevice();
    final StepPattern original = await seed(a);
    final Uint8List bytes = (await a.export.project('proj1')).valueOrNull!.bytes;

    final Result<ImportResult> imported = await a.import(bytes);
    expect(imported.failureOrNull, isNull);

    final String copyId = imported.valueOrNull!.importedIds.single;
    expect(copyId, isNot('proj1'));
    final StepPattern copy = (await a.steps.getByProject(copyId)).valueOrNull!;
    expect(copy.id, isNot(original.id));
    expect(copy.images.single.id, isNot('img1'));
    expect(copy.sections.single.steps.first.imageIds, <String>[copy.images.single.id]);
    expect((await a.steps.getByProject('proj1')).valueOrNull!.images.single.id, 'img1');
    expect(a.filesOnDisk(), hasLength(2));
  });

  test('проект-инструкция без содержимого уезжает пустым, без инструкции файл остаётся прежней версии', () async {
    final BiserDevice a = BiserDevice();
    await a.projects.save(sampleProject('empty', kind: ContentKind.steps));
    final Uint8List bytes = await a.backupBytes();
    final BiserBundle bundle = const ZipBiserCodec().decode(bytes).valueOrNull!;
    expect(bundle.projects.single.steps, isNull);
    expect(bundle.formatVersion, 1);
  });

  test('картинка не PNG (JPG из шаблона): экспорт её пропускает, копия восстанавливается', () async {
    final BiserDevice a = BiserDevice();
    final BiserDevice b = BiserDevice();
    await seed(a);
    await a.realFiles.write('step_patterns/pattern1/img1.png', Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2]));

    expect((await b.import(await a.backupBytes())).failureOrNull, isNull);
    expect((await b.steps.getByProject('proj1')).valueOrNull!.images, isEmpty);
  });

  test('потерянный файл картинки: инструкция всё равно экспортируется, без этой картинки', () async {
    final BiserDevice a = BiserDevice();
    final BiserDevice b = BiserDevice();
    await seed(a);
    await a.realFiles.delete('step_patterns/pattern1/img1.png');

    expect((await b.import(await a.backupBytes())).failureOrNull, isNull);

    final StepPattern restored = (await b.steps.getByProject('proj1')).valueOrNull!;
    expect(restored.images, isEmpty);
    expect(restored.sections.single.steps.first.imageIds, <String>['img1'], reason: 'ссылка в шаге не ошибка');
  });

  test('файл, где картинка инструкции не PNG, отклоняется целиком', () async {
    final BiserDevice a = BiserDevice();
    await seed(a);
    final BiserBundle bundle = const ZipBiserCodec().decode(await a.backupBytes()).valueOrNull!;
    final BiserBundle broken = BiserBundle(
      kind: bundle.kind,
      exportedAt: bundle.exportedAt,
      appVersion: bundle.appVersion,
      projects: bundle.projects,
      files: <String, Uint8List>{
        for (final String k in bundle.files.keys) k: Uint8List.fromList(<int>[1, 2, 3]),
      },
    );
    final Result<BiserBundle> decoded = const ZipBiserCodec().decode(const ZipBiserCodec().encode(broken).valueOrNull!);
    expect(decoded.failureOrNull, isA<ValidationFailure>());
  });
}
