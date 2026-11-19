import 'dart:convert';
import 'dart:typed_data';

import 'package:beading/core/id_generator.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/image_to_grid/drift_image_recipe_index.dart';
import 'package:beading/data/sync/drift_sync_store.dart';
import 'package:beading/data/sync/sync_entity_mapper.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/image_recipe.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/importance_brush.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:beading/domain/sync/sync_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/sync/sync_fakes.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_image_pattern.dart';

class _Device implements DeviceIdProvider {
  const _Device(this.id);

  final String id;

  @override
  Future<Result<String>> deviceId() async => Success<String>(id);
}

/// Рецепт мастера между двумя устройствами (T96): параметры строкой, путь фото тот же.
void main() {
  late FakeRemote remote;
  late AppDatabase phone;
  late AppDatabase mac;
  late FakeFileStore phoneFiles;
  late FakeClock clock;

  final ImageRecipe recipe = ImageRecipe(
    source: Uint8List.fromList(<int>[1, 2, 3]),
    quarterTurns: 1,
    crop: const CropRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8),
    brush: ImportanceBrush.empty,
    settings: const ImageToGridSettings(columns: 120),
  );

  Future<SyncReport> sync(AppDatabase db) {
    final DriftSyncStore store = DriftSyncStore(
      ctx: SyncDbContext(db: db, ids: UuidV7IdGenerator()),
    );
    return SyncEngine(store: store, remote: remote, schema: store.schema).run(userId: 'nastya');
  }

  DriftImageRecipeIndex index(AppDatabase db, String device) =>
      DriftImageRecipeIndex(db: db, deviceIds: _Device(device), clock: clock);

  Future<void> seedProject(AppDatabase db) async {
    await db.customStatement(
      "INSERT INTO projects (id, created_at, updated_at, device_id, name, technique, content_kind, last_worked_at) VALUES ('p1', 5, 5, 'd', 'Кот', 'crossStitch', 'grid', 1)",
    );
    await db.customStatement(
      "INSERT INTO grid_patterns (id, created_at, updated_at, device_id, project_id, geometry, width, height, cell_metrics, cells, cells_codec_version) VALUES ('g1', 5, 5, 'd', 'p1', 'square', 2, 2, 'x', X'00', 1)",
    );
  }

  setUp(() {
    remote = FakeRemote();
    phone = AppDatabase(NativeDatabase.memory());
    mac = AppDatabase(NativeDatabase.memory());
    phoneFiles = FakeFileStore();
    clock = FakeClock(DateTime.utc(2026, 11, 19));
    addTearDown(phone.close);
    addTearDown(mac.close);
  });

  test('рецепт, сохранённый на телефоне, доезжает до Mac: параметры и путь фото', () async {
    await seedProject(phone);
    final ImageRecipeStore store = ImageRecipeStore(phoneFiles, index: index(phone, 'phone'));
    expect((await store.save('p1', recipe)).isSuccess, isTrue);
    expect(phoneFiles.files.containsKey('recipes/p1.json'), isFalse, reason: 'параметры теперь в базе');

    await sync(phone);
    await sync(mac);

    final String? params = await index(mac, 'mac').params('p1');
    expect(params, ImageRecipeCodec.encode(recipe));
    final List<Map<String, Object?>> rows = await SyncDbContext(
      db: mac,
      ids: UuidV7IdGenerator(),
    ).query('SELECT path FROM image_recipes');
    expect(rows.single['path'], 'recipes/p1.src');

    // Фото на Mac кладёт Storage; здесь его кладём сами и проверяем, что рецепт открывается.
    final FakeFileStore macFiles = FakeFileStore()..files['recipes/p1.src'] = recipe.source;
    expect(await ImageRecipeStore(macFiles, index: index(mac, 'mac')).load('p1'), recipe);
  });

  test('удаление рецепта уезжает надгробием', () async {
    await seedProject(phone);
    final ImageRecipeStore store = ImageRecipeStore(phoneFiles, index: index(phone, 'phone'));
    await store.save('p1', recipe);
    await sync(phone);
    await sync(mac);

    clock.advance(const Duration(seconds: 1));
    await store.delete('p1');
    await sync(phone);
    await sync(mac);

    expect(await index(mac, 'mac').params('p1'), isNull);
    expect(phoneFiles.files, isEmpty);
  });

  test('рецепт до T96 (только файлы) переносится в базу при запуске и уезжает', () async {
    await seedProject(phone);
    phoneFiles.files['recipes/p1.src'] = recipe.source;
    phoneFiles.files['recipes/p1.json'] = Uint8List.fromList(utf8.encode(ImageRecipeCodec.encode(recipe)));
    final ImageRecipeStore store = ImageRecipeStore(phoneFiles, index: index(phone, 'phone'));

    await store.adoptLegacy();

    expect(phoneFiles.files.containsKey('recipes/p1.json'), isFalse);
    expect(await store.load('p1'), recipe);
    await sync(phone);
    await sync(mac);
    expect(await index(mac, 'mac').params('p1'), ImageRecipeCodec.encode(recipe));
  });

  test('без фото старый файл параметров не переносится', () async {
    await seedProject(phone);
    phoneFiles.files['recipes/p1.json'] = Uint8List.fromList(utf8.encode(ImageRecipeCodec.encode(recipe)));
    await ImageRecipeStore(phoneFiles, index: index(phone, 'phone')).adoptLegacy();
    expect(await index(phone, 'phone').params('p1'), isNull);
  });

  test('повторное сохранение двигает updated_at вперёд даже при отставших часах', () async {
    await seedProject(phone);
    final DriftImageRecipeIndex idx = index(phone, 'phone');
    await idx.put('p1', params: 'a', sourcePath: 'recipes/p1.src');
    await idx.put('p1', params: 'b', sourcePath: 'recipes/p1.src');
    final List<Map<String, Object?>> rows = await SyncDbContext(
      db: phone,
      ids: UuidV7IdGenerator(),
    ).query('SELECT created_at, updated_at, params FROM image_recipes');
    expect(rows.single['params'], 'b');
    expect(rows.single['updated_at']! as int, greaterThan(rows.single['created_at']! as int));
  });
}
