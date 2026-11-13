import 'dart:io';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/stitch_import/xml_oxs_decoder.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:beading/domain/stitch_import/import_oxs.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/sharing/biser_roundtrip_test.dart' show populate;
import '../../support/biser_device.dart';
import '../../support/biser_samples.dart';
import '../../support/fake_biser.dart';

void main() {
  late BiserDevice device;
  late FakeFileSharer sharer;
  late FakeBiserFilePicker picker;
  late DataTransferCubit cubit;
  late Uint8List backup;

  setUp(() async {
    final BiserDevice source = BiserDevice();
    await populate(source, randomBundle(4, projects: 2));
    backup = await source.backupBytes();

    device = BiserDevice();
    sharer = FakeFileSharer();
    picker = FakeBiserFilePicker();
    cubit = DataTransferCubit(export: device.export, import: device.import, sharer: sharer, picker: picker);
    addTearDown(cubit.close);
  });

  test('резервная копия отдаётся листу «Поделиться» с именем .biser и кнопкой-источником', () async {
    await populate(device, randomBundle(1, projects: 1));
    const ShareOrigin origin = ShareOrigin(left: 1, top: 2, width: 3, height: 4);
    await cubit.backup(origin: origin);

    expect(sharer.shared.single.fileName, matches(RegExp(r'^Biser-backup-\d{4}-\d{2}-\d{2}\.biser$')));
    expect(sharer.shared.single.origin, origin);
    expect(cubit.state, const DataTransferState());
  });

  test('поделиться проектом', () async {
    await populate(device, randomBundle(1, projects: 1));
    final String id = (await device.allProjects()).single.id;
    await cubit.shareProject(id);
    expect(sharer.shared, hasLength(1));
  });

  test('ошибка листа «Поделиться» попадает в состояние', () async {
    sharer.failure = const UnexpectedFailure('boom');
    await cubit.backup();
    expect(cubit.state.failure, const UnexpectedFailure('boom'));
    cubit.dismiss();
    expect(cubit.state.failure, isNull);
  });

  test('нет такого проекта — ошибка, лист не открывается', () async {
    await cubit.shareProject('нет');
    expect(cubit.state.failure, isA<NotFoundFailure>());
    expect(sharer.shared, isEmpty);
  });

  test('восстановление: файл выбран → обзор → подтверждение → итог', () async {
    picker.next = Success<BiserFile?>(BiserFile(name: 'a.biser', bytes: backup));
    await cubit.pickAndPreview();
    expect(cubit.state.pending!.preview.items, hasLength(2));

    await cubit.confirmImport(ConflictChoice.asNew);
    expect(cubit.state.imported!.importedIds, hasLength(2));
    expect(await device.allProjects(), hasLength(2));
    cubit.dismiss();
    expect(cubit.state, const DataTransferState());
  });

  test('файл .oxs (T42): создаётся вышивка сразу, без обзора', () async {
    final DataTransferCubit withOxs = DataTransferCubit(
      export: device.export,
      import: device.import,
      sharer: sharer,
      picker: picker,
      importOxs: ImportOxs(
        decoder: const XmlOxsDecoder(),
        createPattern: CreateGridPattern(
          createProject: CreateProject(repository: device.projects, ids: device.ids, clock: device.clock),
          projects: device.projects,
          patterns: device.grids,
          ids: device.ids,
        ),
      ),
    );
    addTearDown(withOxs.close);
    await withOxs.openFile(BiserFile(name: 'Rose.OXS', bytes: File('test/fixtures/oxs/sample.oxs').readAsBytesSync()));
    expect(withOxs.state.imported!.importedIds, hasLength(1));
    expect(withOxs.state.pending, isNull);
    expect((await device.allProjects()).single.craft, Craft.crossStitch);
  });

  test('выбор файла отменили — ничего не происходит', () async {
    await cubit.pickAndPreview();
    expect(cubit.state, const DataTransferState());
  });

  test('ошибка выбора файла', () async {
    picker.next = const Err<BiserFile?>(StorageFailure('нет доступа'));
    await cubit.pickAndPreview();
    expect(cubit.state.failure, const StorageFailure('нет доступа'));
  });

  test('повреждённый файл: понятная ошибка, ничего не импортировано', () async {
    picker.next = Success<BiserFile?>(BiserFile(name: 'x.biser', bytes: Uint8List.fromList(<int>[1, 2, 3])));
    await cubit.pickAndPreview();
    expect(cubit.state.failure, isA<ValidationFailure>());
    expect(cubit.state.pending, isNull);
    expect(await device.allProjects(), isEmpty);
  });

  test('файл без проектов — ошибка', () async {
    final BiserDevice empty = BiserDevice();
    picker.next = Success<BiserFile?>(BiserFile(name: 'e.biser', bytes: await empty.backupBytes()));
    await cubit.pickAndPreview();
    expect(cubit.state.failure, isA<ValidationFailure>());
  });

  test('файл, открытый системой, идёт тем же путём; пока ждём ответа, второй игнорируется', () async {
    await cubit.openFile(BiserFile(name: 'a.biser', bytes: backup));
    expect(cubit.state.pending, isNotNull);
    await cubit.openFile(BiserFile(name: 'b.biser', bytes: Uint8List(0)));
    expect(cubit.state.pending, isNotNull);
    expect(cubit.state.failure, isNull);
  });

  test('отказ от импорта (dismiss) и confirmImport без файла ничего не пишут', () async {
    await cubit.confirmImport(ConflictChoice.asNew);
    expect(await device.allProjects(), isEmpty);
    await cubit.openFile(BiserFile(name: 'a.biser', bytes: backup));
    cubit.dismiss();
    expect(cubit.state.pending, isNull);
  });

  test('ошибка чтения файла от системы', () {
    cubit.reportFailure(const StorageFailure('x'));
    expect(cubit.state.failure, const StorageFailure('x'));
  });
}
