import 'dart:convert';

import 'package:beading/data/sync/sync_entity_mapper.dart';
import 'package:beading/domain/sync/sync_record.dart';

/// Мапперы всех синхронизируемых сущностей по таблице ключей из ADR-0006.
List<SyncEntityMapper> buildSyncMappers(SyncDbContext ctx) => <SyncEntityMapper>[
  ProjectMapper(ctx),
  FlossStockMapper(ctx),
  BeadStockMapper(ctx),
  SettingMapper(ctx),
  ImagePatternMapper(ctx),
  GridPatternMapper(ctx),
  WorkSessionMapper(ctx),
  ImagePatternPageMapper(ctx),
  GridCursorMapper(ctx),
  ProgressRowMapper(ctx),
  ProgressCellMapper(ctx),
  PageWorkMapper(ctx),
  BookWorkMapper(ctx),
];

const String _common = 'created_at, updated_at, deleted_at, device_id';

String _projectOf(String syncId) => syncId.split(':').first;

int _positionOf(String syncId) => int.parse(syncId.split(':').last);

class ProjectMapper extends SyncEntityMapper {
  ProjectMapper(super.ctx);

  @override
  String get entity => 'project';

  @override
  int get rank => 0;

  @override
  String? parentKey(SyncRecord record) => null;

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query('SELECT id FROM projects')) r['id']! as String,
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    final Row? r = await ctx.first('SELECT * FROM projects WHERE id = ?', <Object?>[syncId]);
    if (r == null) {
      return null;
    }
    // Обложка (`cover_path`) — файл на устройстве, в обмен не входит.
    return build(syncId, r, <String, Object?>{
      'name': r['name'],
      'craft': r['craft'],
      'status': r['status'],
      'technique': r['technique'],
      'content_kind': r['content_kind'],
      'notes': r['notes'],
      'last_worked_at': r['last_worked_at'],
    });
  }

  @override
  Future<void> apply(SyncRecord r) async {
    if (r.isDeleted) {
      await tombstone('projects', 'id = ?', <Object?>[r.syncId], r);
      return;
    }
    final Row? existing = await ctx.first('SELECT 1 AS x FROM projects WHERE id = ?', <Object?>[r.syncId]);
    final Map<String, Object?> d = r.data;
    if (existing == null) {
      await ctx.run(
        'INSERT INTO projects (id, name, craft, status, technique, content_kind, notes, last_worked_at, $_common) VALUES (?,?,?,?,?,?,?,?,?,?,NULL,?)',
        <Object?>[
          r.syncId,
          d['name'],
          d['craft'],
          d['status'],
          d['technique'],
          d['content_kind'],
          d['notes'],
          d['last_worked_at'],
          createdAt(r),
          r.updatedAt,
          r.deviceId,
        ],
      );
    } else {
      await ctx.run(
        'UPDATE projects SET name=?, craft=?, status=?, technique=?, content_kind=?, notes=?, last_worked_at=?, updated_at=?, deleted_at=NULL, device_id=? WHERE id=?',
        <Object?>[
          d['name'],
          d['craft'],
          d['status'],
          d['technique'],
          d['content_kind'],
          d['notes'],
          d['last_worked_at'],
          r.updatedAt,
          r.deviceId,
          r.syncId,
        ],
      );
    }
  }
}

class FlossStockMapper extends SyncEntityMapper {
  FlossStockMapper(super.ctx);

  @override
  String get entity => 'floss_stock';

  @override
  int get rank => 0;

  @override
  String? parentKey(SyncRecord record) => null;

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query('SELECT brand, code FROM floss_stock')) "${r['brand']}:${r['code']}",
  ];

  (String, String) _split(String syncId) {
    final int i = syncId.indexOf(':');
    return (syncId.substring(0, i), syncId.substring(i + 1));
  }

  @override
  Future<SyncRecord?> read(String syncId) async {
    final (String brand, String code) = _split(syncId);
    final Row? r = await ctx.first('SELECT * FROM floss_stock WHERE brand = ? AND code = ?', <Object?>[brand, code]);
    return r == null ? null : build(syncId, r, <String, Object?>{'skeins': r['skeins']});
  }

  @override
  Future<void> apply(SyncRecord r) async {
    final (String brand, String code) = _split(r.syncId);
    if (r.isDeleted) {
      await tombstone('floss_stock', 'brand = ? AND code = ?', <Object?>[brand, code], r);
      return;
    }
    final Row? existing = await ctx.first('SELECT 1 AS x FROM floss_stock WHERE brand = ? AND code = ?', <Object?>[
      brand,
      code,
    ]);
    if (existing == null) {
      await ctx.run(
        'INSERT INTO floss_stock (id, brand, code, skeins, $_common) VALUES (?,?,?,?,?,?,NULL,?)',
        <Object?>[ctx.ids.next(), brand, code, r.data['skeins'], createdAt(r), r.updatedAt, r.deviceId],
      );
    } else {
      await ctx.run(
        'UPDATE floss_stock SET skeins=?, updated_at=?, deleted_at=NULL, device_id=? WHERE brand=? AND code=?',
        <Object?>[r.data['skeins'], r.updatedAt, r.deviceId, brand, code],
      );
    }
  }
}

class BeadStockMapper extends SyncEntityMapper {
  BeadStockMapper(super.ctx);

  @override
  String get entity => 'bead_stock';

  @override
  int get rank => 0;

  @override
  String? parentKey(SyncRecord record) => null;

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query('SELECT brand, code FROM bead_stock')) "${r['brand']}:${r['code']}",
  ];

  (String, String) _split(String syncId) {
    final int i = syncId.indexOf(':');
    return (syncId.substring(0, i), syncId.substring(i + 1));
  }

  @override
  Future<SyncRecord?> read(String syncId) async {
    final (String brand, String code) = _split(syncId);
    final Row? r = await ctx.first('SELECT * FROM bead_stock WHERE brand = ? AND code = ?', <Object?>[brand, code]);
    return r == null ? null : build(syncId, r, <String, Object?>{'grams': r['grams']});
  }

  @override
  Future<void> apply(SyncRecord r) async {
    final (String brand, String code) = _split(r.syncId);
    if (r.isDeleted) {
      await tombstone('bead_stock', 'brand = ? AND code = ?', <Object?>[brand, code], r);
      return;
    }
    final Row? existing = await ctx.first('SELECT 1 AS x FROM bead_stock WHERE brand = ? AND code = ?', <Object?>[
      brand,
      code,
    ]);
    if (existing == null) {
      await ctx.run(
        'INSERT INTO bead_stock (id, brand, code, grams, $_common) VALUES (?,?,?,?,?,?,NULL,?)',
        <Object?>[ctx.ids.next(), brand, code, r.data['grams'], createdAt(r), r.updatedAt, r.deviceId],
      );
    } else {
      await ctx.run(
        'UPDATE bead_stock SET grams=?, updated_at=?, deleted_at=NULL, device_id=? WHERE brand=? AND code=?',
        <Object?>[r.data['grams'], r.updatedAt, r.deviceId, brand, code],
      );
    }
  }
}

class SettingMapper extends SyncEntityMapper {
  SettingMapper(super.ctx);

  @override
  String get entity => 'setting';

  @override
  int get rank => 0;

  @override
  String? parentKey(SyncRecord record) => null;

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query("SELECT \"key\" FROM settings WHERE \"key\" NOT LIKE 'local.%'"))
      r['key']! as String,
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    if (syncId.startsWith('local.')) {
      return null;
    }
    final Row? r = await ctx.first('SELECT * FROM settings WHERE "key" = ?', <Object?>[syncId]);
    return r == null ? null : build(syncId, r, <String, Object?>{'value': r['value']});
  }

  @override
  Future<void> apply(SyncRecord r) async {
    if (r.syncId.startsWith('local.')) {
      return; // настройки устройства из обмена не принимаются
    }
    if (r.isDeleted) {
      await tombstone('settings', '"key" = ?', <Object?>[r.syncId], r);
      return;
    }
    await ctx.run(
      'INSERT INTO settings ("key", value, $_common) VALUES (?,?,?,?,NULL,?) '
      'ON CONFLICT("key") DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at, deleted_at=NULL, device_id=excluded.device_id',
      <Object?>[r.syncId, r.data['value'], createdAt(r), r.updatedAt, r.deviceId],
    );
  }
}

class ImagePatternMapper extends SyncEntityMapper {
  ImagePatternMapper(super.ctx);

  @override
  String get entity => 'image_pattern';

  @override
  int get rank => 1;

  @override
  String? parentKey(SyncRecord record) => 'project/${record.syncId}';

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query('SELECT project_id FROM image_patterns')) r['project_id']! as String,
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    final Row? r = await ctx.first('SELECT * FROM image_patterns WHERE project_id = ?', <Object?>[syncId]);
    return r == null ? null : build(syncId, r, const <String, Object?>{});
  }

  @override
  Future<void> apply(SyncRecord r) async {
    if (r.isDeleted) {
      await tombstone('image_patterns', 'project_id = ?', <Object?>[r.syncId], r);
      return;
    }
    final Row? existing = await ctx.first('SELECT 1 AS x FROM image_patterns WHERE project_id = ?', <Object?>[
      r.syncId,
    ]);
    if (existing == null) {
      await ctx.run(
        'INSERT INTO image_patterns (id, project_id, $_common) VALUES (?,?,?,?,NULL,?)',
        <Object?>[ctx.ids.next(), r.syncId, createdAt(r), r.updatedAt, r.deviceId],
      );
    } else {
      await ctx.run(
        'UPDATE image_patterns SET updated_at=?, deleted_at=NULL, device_id=? WHERE project_id=?',
        <Object?>[r.updatedAt, r.deviceId, r.syncId],
      );
    }
  }
}

class GridPatternMapper extends SyncEntityMapper {
  GridPatternMapper(super.ctx);

  @override
  String get entity => 'grid_pattern';

  @override
  int get rank => 1;

  @override
  String? parentKey(SyncRecord record) => 'project/${record.syncId}';

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query('SELECT project_id FROM grid_patterns')) r['project_id']! as String,
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    final Row? r = await ctx.first('SELECT * FROM grid_patterns WHERE project_id = ?', <Object?>[syncId]);
    if (r == null) {
      return null;
    }
    final List<Row> colors = await ctx.query(
      'SELECT position, rgb, name, components, finish, symbol FROM pattern_colors WHERE grid_pattern_id = ? AND deleted_at IS NULL ORDER BY position',
      <Object?>[r['id']],
    );
    // Позиция «остановилась здесь» уходит отдельной сущностью grid_cursor (R-09).
    return build(syncId, r, <String, Object?>{
      'geometry': r['geometry'],
      'geometry_drop': r['geometry_drop'],
      'width': r['width'],
      'height': r['height'],
      'cell_metrics': r['cell_metrics'],
      'cells': b64(r['cells']),
      'cells_codec_version': r['cells_codec_version'],
      'layers': b64(r['layers']),
      'layers_codec_version': r['layers_codec_version'],
      'colors': <Object?>[
        for (final Row c in colors) <String, Object?>{...c},
      ],
    });
  }

  @override
  Future<void> apply(SyncRecord r) async {
    if (r.isDeleted) {
      await tombstone('grid_patterns', 'project_id = ?', <Object?>[r.syncId], r);
      return;
    }
    final Map<String, Object?> d = r.data;
    final Row? existing = await ctx.first('SELECT id FROM grid_patterns WHERE project_id = ?', <Object?>[r.syncId]);
    final String id;
    if (existing == null) {
      id = ctx.ids.next();
      await ctx.run(
        'INSERT INTO grid_patterns (id, project_id, geometry, geometry_drop, width, height, cell_metrics, cells, cells_codec_version, layers, layers_codec_version, $_common) '
        'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,NULL,?)',
        <Object?>[
          id,
          r.syncId,
          d['geometry'],
          d['geometry_drop'],
          d['width'],
          d['height'],
          d['cell_metrics'],
          unb64(d['cells']),
          d['cells_codec_version'],
          unb64(d['layers']),
          d['layers_codec_version'],
          createdAt(r),
          r.updatedAt,
          r.deviceId,
        ],
      );
    } else {
      id = existing['id']! as String;
      await ctx.run(
        'UPDATE grid_patterns SET geometry=?, geometry_drop=?, width=?, height=?, cell_metrics=?, cells=?, cells_codec_version=?, layers=?, layers_codec_version=?, '
        'updated_at=?, deleted_at=NULL, device_id=? WHERE id=?',
        <Object?>[
          d['geometry'],
          d['geometry_drop'],
          d['width'],
          d['height'],
          d['cell_metrics'],
          unb64(d['cells']),
          d['cells_codec_version'],
          unb64(d['layers']),
          d['layers_codec_version'],
          r.updatedAt,
          r.deviceId,
          id,
        ],
      );
    }
    // Палитра — часть записи схемы: заменяется целиком.
    await ctx.run('DELETE FROM pattern_colors WHERE grid_pattern_id = ?', <Object?>[id]);
    for (final Object? c in (d['colors'] as List<Object?>?) ?? const <Object?>[]) {
      final Row color = c! as Row;
      await ctx.run(
        'INSERT INTO pattern_colors (id, grid_pattern_id, position, rgb, name, components, finish, symbol, $_common) VALUES (?,?,?,?,?,?,?,?,?,?,NULL,?)',
        <Object?>[
          ctx.ids.next(),
          id,
          color['position'],
          color['rgb'],
          color['name'],
          color['components'],
          color['finish'],
          color['symbol'],
          createdAt(r),
          r.updatedAt,
          r.deviceId,
        ],
      );
    }
  }
}

class WorkSessionMapper extends SyncEntityMapper {
  WorkSessionMapper(super.ctx);

  @override
  String get entity => 'work_session';

  @override
  int get rank => 1;

  @override
  String? parentKey(SyncRecord record) => 'project/${record.data['project_id']}';

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query('SELECT id FROM work_sessions')) r['id']! as String,
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    final Row? r = await ctx.first('SELECT * FROM work_sessions WHERE id = ?', <Object?>[syncId]);
    return r == null
        ? null
        : build(syncId, r, <String, Object?>{
            'project_id': r['project_id'],
            'started_at': r['started_at'],
            'ended_at': r['ended_at'],
          });
  }

  @override
  Future<void> apply(SyncRecord r) async {
    if (r.isDeleted) {
      await tombstone('work_sessions', 'id = ?', <Object?>[r.syncId], r);
      return;
    }
    final Map<String, Object?> d = r.data;
    await ctx.run(
      'INSERT INTO work_sessions (id, project_id, started_at, ended_at, $_common) VALUES (?,?,?,?,?,?,NULL,?) '
      'ON CONFLICT(id) DO UPDATE SET project_id=excluded.project_id, started_at=excluded.started_at, ended_at=excluded.ended_at, '
      'updated_at=excluded.updated_at, deleted_at=NULL, device_id=excluded.device_id',
      <Object?>[r.syncId, d['project_id'], d['started_at'], d['ended_at'], createdAt(r), r.updatedAt, r.deviceId],
    );
  }
}

class ImagePatternPageMapper extends SyncEntityMapper {
  ImagePatternPageMapper(super.ctx);

  @override
  String get entity => 'image_pattern_page';

  @override
  int get rank => 2;

  @override
  String? parentKey(SyncRecord record) => 'image_pattern/${_projectOf(record.syncId)}';

  static const String _select =
      'SELECT p.*, i.project_id AS project_id FROM image_pattern_pages p JOIN image_patterns i ON i.id = p.pattern_id';

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query(_select)) "${r['project_id']}:${r['position']}",
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    final Row? r = await ctx.first('$_select WHERE i.project_id = ? AND p.position = ?', <Object?>[
      _projectOf(syncId),
      _positionOf(syncId),
    ]);
    // Файл страницы (`path`) передаётся через Storage в слое транспорта; здесь только его относительное имя.
    return r == null
        ? null
        : build(syncId, r, <String, Object?>{'path': r['path'], 'width': r['width'], 'height': r['height']});
  }

  @override
  Future<void> apply(SyncRecord r) async {
    final Row? pattern = await ctx.first('SELECT id FROM image_patterns WHERE project_id = ?', <Object?>[
      _projectOf(r.syncId),
    ]);
    if (pattern == null) {
      return;
    }
    final String patternId = pattern['id']! as String;
    final int position = _positionOf(r.syncId);
    if (r.isDeleted) {
      await tombstone('image_pattern_pages', 'pattern_id = ? AND position = ?', <Object?>[patternId, position], r);
      return;
    }
    final Map<String, Object?> d = r.data;
    final Row? existing = await ctx.first(
      'SELECT 1 AS x FROM image_pattern_pages WHERE pattern_id = ? AND position = ?',
      <Object?>[patternId, position],
    );
    if (existing == null) {
      await ctx.run(
        'INSERT INTO image_pattern_pages (id, pattern_id, position, path, width, height, $_common) VALUES (?,?,?,?,?,?,?,?,NULL,?)',
        <Object?>[
          ctx.ids.next(),
          patternId,
          position,
          d['path'],
          d['width'],
          d['height'],
          createdAt(r),
          r.updatedAt,
          r.deviceId,
        ],
      );
    } else {
      await ctx.run(
        'UPDATE image_pattern_pages SET path=?, width=?, height=?, updated_at=?, deleted_at=NULL, device_id=? WHERE pattern_id=? AND position=?',
        <Object?>[d['path'], d['width'], d['height'], r.updatedAt, r.deviceId, patternId, position],
      );
    }
  }
}

/// Позиция «остановилась здесь» (R-09): живёт колонками `grid_patterns`, обменивается отдельной сущностью со своим временем.
class GridCursorMapper extends SyncEntityMapper {
  GridCursorMapper(super.ctx);

  @override
  String get entity => 'grid_cursor';

  @override
  int get rank => 2;

  @override
  String? parentKey(SyncRecord record) => 'grid_pattern/${record.syncId}';

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query(
      'SELECT project_id FROM grid_patterns WHERE current_row IS NOT NULL OR cursor_updated_at IS NOT NULL',
    ))
      r['project_id']! as String,
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    final Row? r = await ctx.first('SELECT * FROM grid_patterns WHERE project_id = ?', <Object?>[syncId]);
    if (r == null) {
      return null;
    }
    final int? deletedAt = r['deleted_at'] as int?;
    if (deletedAt != null) {
      return build(syncId, r, const <String, Object?>{});
    }
    return build(
      syncId,
      <String, Object?>{
        ...r,
        'updated_at': r['cursor_updated_at'] ?? r['updated_at'],
        'device_id': r['cursor_device_id'] ?? r['device_id'],
      },
      <String, Object?>{'current_row': r['current_row'], 'current_bead': r['current_bead']},
    );
  }

  @override
  Future<void> apply(SyncRecord r) async {
    if (r.isDeleted) {
      return; // удаление схемы приходит записью grid_pattern
    }
    await ctx.run(
      'UPDATE grid_patterns SET current_row=?, current_bead=?, cursor_updated_at=?, cursor_device_id=? WHERE project_id=?',
      <Object?>[r.data['current_row'], r.data['current_bead'], r.updatedAt, r.deviceId, r.syncId],
    );
  }
}

class ProgressRowMapper extends SyncEntityMapper {
  ProgressRowMapper(super.ctx);

  @override
  String get entity => 'progress_row';

  @override
  int get rank => 2;

  @override
  String? parentKey(SyncRecord record) => 'grid_pattern/${_projectOf(record.syncId)}';

  static const String _select =
      'SELECT r.*, g.project_id AS project_id FROM grid_progress_rows r JOIN grid_patterns g ON g.id = r.grid_pattern_id';

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query(_select)) "${r['project_id']}:${r['row_index']}",
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    final Row? r = await ctx.first('$_select WHERE g.project_id = ? AND r.row_index = ?', <Object?>[
      _projectOf(syncId),
      _positionOf(syncId),
    ]);
    return r == null ? null : build(syncId, r, <String, Object?>{'completed_at': r['completed_at']});
  }

  @override
  Future<void> apply(SyncRecord r) async {
    final Row? grid = await ctx.first('SELECT id FROM grid_patterns WHERE project_id = ?', <Object?>[
      _projectOf(r.syncId),
    ]);
    if (grid == null) {
      return;
    }
    final String gridId = grid['id']! as String;
    final int rowIndex = _positionOf(r.syncId);
    if (r.isDeleted) {
      await tombstone('grid_progress_rows', 'grid_pattern_id = ? AND row_index = ?', <Object?>[gridId, rowIndex], r);
      return;
    }
    await ctx.run(
      'INSERT INTO grid_progress_rows (id, grid_pattern_id, row_index, completed_at, $_common) VALUES (?,?,?,?,?,?,NULL,?) '
      'ON CONFLICT(grid_pattern_id, row_index) DO UPDATE SET completed_at=excluded.completed_at, updated_at=excluded.updated_at, '
      'deleted_at=NULL, device_id=excluded.device_id',
      <Object?>[ctx.ids.next(), gridId, rowIndex, r.data['completed_at'], createdAt(r), r.updatedAt, r.deviceId],
    );
  }
}

class ProgressCellMapper extends SyncEntityMapper {
  ProgressCellMapper(super.ctx);

  @override
  String get entity => 'progress_cell';

  @override
  int get rank => 2;

  @override
  String? parentKey(SyncRecord record) => 'grid_pattern/${_projectOf(record.syncId)}';

  static const String _select =
      'SELECT c.*, g.project_id AS project_id FROM grid_progress_cells c JOIN grid_patterns g ON g.id = c.grid_pattern_id';

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query(_select)) "${r['project_id']}:${r['block_index']}",
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    final Row? r = await ctx.first('$_select WHERE g.project_id = ? AND c.block_index = ?', <Object?>[
      _projectOf(syncId),
      _positionOf(syncId),
    ]);
    return r == null ? null : build(syncId, r, <String, Object?>{'bits': b64(r['bits'])});
  }

  @override
  Future<void> apply(SyncRecord r) async {
    final Row? grid = await ctx.first('SELECT id FROM grid_patterns WHERE project_id = ?', <Object?>[
      _projectOf(r.syncId),
    ]);
    if (grid == null) {
      return;
    }
    final String gridId = grid['id']! as String;
    final int block = _positionOf(r.syncId);
    if (r.isDeleted) {
      await tombstone('grid_progress_cells', 'grid_pattern_id = ? AND block_index = ?', <Object?>[gridId, block], r);
      return;
    }
    await ctx.run(
      'INSERT INTO grid_progress_cells (id, grid_pattern_id, block_index, bits, $_common) VALUES (?,?,?,?,?,?,NULL,?) '
      'ON CONFLICT(grid_pattern_id, block_index) DO UPDATE SET bits=excluded.bits, updated_at=excluded.updated_at, '
      'deleted_at=NULL, device_id=excluded.device_id',
      <Object?>[ctx.ids.next(), gridId, block, unb64(r.data['bits']), createdAt(r), r.updatedAt, r.deviceId],
    );
  }
}

class PageWorkMapper extends SyncEntityMapper {
  PageWorkMapper(super.ctx);

  @override
  String get entity => 'page_work';

  @override
  int get rank => 3;

  @override
  String? parentKey(SyncRecord record) => 'image_pattern_page/${record.syncId}';

  static const String _select =
      'SELECT w.*, i.project_id AS project_id, p.position AS position FROM page_work_states w '
      'JOIN image_pattern_pages p ON p.id = w.id JOIN image_patterns i ON i.id = p.pattern_id';

  static const List<String> _columns = <String>[
    'ruler_top',
    'ruler_height',
    'ruler_step',
    'ruler_row',
    'highlight',
    'row_direction',
    'zone_top',
    'zone_bottom',
    'zone_left',
    'zone_right',
    'row_count', 'view_scale', 'view_dx', 'view_dy', //
  ];

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query(_select)) "${r['project_id']}:${r['position']}",
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    final Row? r = await ctx.first('$_select WHERE i.project_id = ? AND p.position = ?', <Object?>[
      _projectOf(syncId),
      _positionOf(syncId),
    ]);
    if (r == null) {
      return null;
    }
    return build(syncId, r, <String, Object?>{for (final String c in _columns) c: r[c], 'markup': b64(r['markup'])});
  }

  Future<String?> _pageId(String syncId) async {
    final Row? p = await ctx.first(
      'SELECT p.id AS id FROM image_pattern_pages p JOIN image_patterns i ON i.id = p.pattern_id WHERE i.project_id = ? AND p.position = ?',
      <Object?>[_projectOf(syncId), _positionOf(syncId)],
    );
    return p?['id'] as String?;
  }

  @override
  Future<void> apply(SyncRecord r) async {
    final String? pageId = await _pageId(r.syncId);
    if (pageId == null) {
      return;
    }
    if (r.isDeleted) {
      await tombstone('page_work_states', 'id = ?', <Object?>[pageId], r);
      return;
    }
    final Map<String, Object?> d = r.data;
    final String setters = _columns.map((c) => '$c=excluded.$c').join(', ');
    await ctx.run(
      'INSERT INTO page_work_states (id, ${_columns.join(', ')}, markup, $_common) VALUES (?,${List<String>.filled(_columns.length, '?').join(',')},?,?,?,NULL,?) '
      'ON CONFLICT(id) DO UPDATE SET $setters, markup=excluded.markup, updated_at=excluded.updated_at, deleted_at=NULL, device_id=excluded.device_id',
      <Object?>[
        pageId,
        for (final String c in _columns) d[c],
        unb64(d['markup']),
        createdAt(r),
        r.updatedAt,
        r.deviceId,
      ],
    );
  }
}

class BookWorkMapper extends SyncEntityMapper {
  BookWorkMapper(super.ctx);

  @override
  String get entity => 'book_work';

  @override
  int get rank => 4;

  @override
  String? parentKey(SyncRecord record) => 'image_pattern/${record.syncId}';

  static const String _select =
      'SELECT b.*, i.project_id AS project_id, p.position AS position FROM book_work_states b '
      'JOIN image_patterns i ON i.id = b.id JOIN image_pattern_pages p ON p.id = b.current_page_id';

  @override
  Future<List<String>> allSyncIds() async => <String>[
    for (final Row r in await ctx.query(_select)) r['project_id']! as String,
  ];

  @override
  Future<SyncRecord?> read(String syncId) async {
    final Row? r = await ctx.first('$_select WHERE i.project_id = ?', <Object?>[syncId]);
    return r == null ? null : build(syncId, r, <String, Object?>{'current_page': r['position']});
  }

  @override
  Future<void> apply(SyncRecord r) async {
    final Row? pattern = await ctx.first('SELECT id FROM image_patterns WHERE project_id = ?', <Object?>[r.syncId]);
    if (pattern == null) {
      return;
    }
    final String patternId = pattern['id']! as String;
    if (r.isDeleted) {
      await tombstone('book_work_states', 'id = ?', <Object?>[patternId], r);
      return;
    }
    final Row? page = await ctx.first(
      'SELECT id FROM image_pattern_pages WHERE pattern_id = ? AND position = ?',
      <Object?>[patternId, r.data['current_page']],
    );
    if (page == null) {
      return; // страница ещё не приехала: запись применится, когда она появится
    }
    await ctx.run(
      'INSERT INTO book_work_states (id, current_page_id, $_common) VALUES (?,?,?,?,NULL,?) '
      'ON CONFLICT(id) DO UPDATE SET current_page_id=excluded.current_page_id, updated_at=excluded.updated_at, deleted_at=NULL, device_id=excluded.device_id',
      <Object?>[patternId, page['id'], createdAt(r), r.updatedAt, r.deviceId],
    );
  }
}

/// JSON-представление нагрузки для теневой копии.
String encodeData(Map<String, Object?> data) => jsonEncode(data);

Map<String, Object?> decodeData(String json) => (jsonDecode(json) as Map<String, dynamic>).cast<String, Object?>();
