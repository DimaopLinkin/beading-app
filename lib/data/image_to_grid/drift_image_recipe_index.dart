import 'dart:math' as math;

import 'package:beading/core/clock.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/domain/image_to_grid/image_recipe.dart';
import 'package:beading/domain/settings/device_id_provider.dart';
import 'package:drift/drift.dart';

/// Рецепты в таблице `image_recipes` (T96). Сам ставит служебные колонки; `updated_at` монотонный (ADR-0006, R-04).
class DriftImageRecipeIndex implements ImageRecipeIndex {
  DriftImageRecipeIndex({required AppDatabase db, required DeviceIdProvider deviceIds, required Clock clock})
    : _db = db,
      _deviceIds = deviceIds,
      _clock = clock;

  final AppDatabase _db;
  final DeviceIdProvider _deviceIds;
  final Clock _clock;

  @override
  Future<String?> params(String projectId) async {
    final ImageRecipeRow? row = await (_db.select(
      _db.imageRecipes,
    )..where((t) => t.id.equals(projectId) & t.deletedAt.isNull())).getSingleOrNull();
    return row?.params;
  }

  @override
  Future<void> put(String projectId, {required String params, required String sourcePath}) async {
    final String deviceId = (await _deviceIds.deviceId()).valueOrNull ?? 'unknown';
    await _db.transaction(() async {
      final ImageRecipeRow? old = await (_db.select(
        _db.imageRecipes,
      )..where((t) => t.id.equals(projectId))).getSingleOrNull();
      final int now = _clock.now().millisecondsSinceEpoch;
      if (old == null) {
        await _db
            .into(_db.imageRecipes)
            .insert(
              ImageRecipesCompanion.insert(
                id: projectId,
                params: params,
                path: sourcePath,
                createdAt: now,
                updatedAt: now,
                deviceId: deviceId,
              ),
            );
        return;
      }
      await (_db.update(_db.imageRecipes)..where((t) => t.id.equals(projectId))).write(
        ImageRecipesCompanion(
          params: Value<String>(params),
          path: Value<String>(sourcePath),
          updatedAt: Value<int>(math.max(now, old.updatedAt + 1)),
          deletedAt: const Value<int?>(null),
          deviceId: Value<String>(deviceId),
        ),
      );
    });
  }

  @override
  Future<void> remove(String projectId) async {
    final String deviceId = (await _deviceIds.deviceId()).valueOrNull ?? 'unknown';
    await _db.transaction(() async {
      final ImageRecipeRow? old = await (_db.select(
        _db.imageRecipes,
      )..where((t) => t.id.equals(projectId) & t.deletedAt.isNull())).getSingleOrNull();
      if (old == null) return;
      final int now = math.max(_clock.now().millisecondsSinceEpoch, old.updatedAt + 1);
      await (_db.update(_db.imageRecipes)..where((t) => t.id.equals(projectId))).write(
        ImageRecipesCompanion(
          updatedAt: Value<int>(now),
          deletedAt: Value<int?>(now),
          deviceId: Value<String>(deviceId),
        ),
      );
    });
  }

  @override
  Future<List<String>> projectsWithoutRecipe() async {
    final List<QueryRow> rows = await _db
        .customSelect(
          'SELECT g.project_id AS id FROM grid_patterns g JOIN projects p ON p.id = g.project_id '
          'WHERE g.deleted_at IS NULL AND p.deleted_at IS NULL '
          'AND NOT EXISTS (SELECT 1 FROM image_recipes r WHERE r.id = g.project_id)',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{_db.gridPatterns, _db.projects, _db.imageRecipes},
        )
        .get();
    return <String>[for (final QueryRow r in rows) r.read<String>('id')];
  }
}
