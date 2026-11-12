import 'dart:convert';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_codec.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/grid_geometry_codec.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/grid_progress.dart';
import 'package:beading/domain/image_pattern/book_work/page_markup.dart';
import 'package:beading/domain/image_pattern/book_work/page_viewport.dart';
import 'package:beading/domain/image_pattern/book_work/page_work.dart';
import 'package:beading/domain/image_pattern/book_work/pattern_zone.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';
import 'package:beading/domain/weaving/work_session.dart';

/// Манифест `manifest.json` файла `.biser`: проекты, схемы (сетка — base64 от `GridCodec`), палитры, прогресс.
/// Картинки страниц в манифесте не лежат, на них ссылаются пути внутри архива.
abstract final class BiserJson {
  static const String formatName = 'biser';
  static const String manifestPath = 'manifest.json';
  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9_-]{1,100}$');

  /// PNG-подпись: проверяем, что файл страницы — действительно картинка.
  static const List<int> _pngSignature = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  static String encode(BiserBundle bundle) => jsonEncode(<String, Object?>{
    'format': formatName,
    'version': bundle.formatVersion,
    'kind': bundle.kind.name,
    'exportedAt': bundle.exportedAt.toUtc().millisecondsSinceEpoch,
    'appVersion': bundle.appVersion,
    'projects': <Object?>[for (final BiserProject p in bundle.projects) _project(p)],
  });

  static Map<String, Object?> _project(BiserProject item) {
    final Project p = item.project;
    return <String, Object?>{
      'id': p.id,
      'name': p.name,
      'status': p.status.name,
      'craft': p.craft.name,
      'technique': p.technique.name,
      'contentKind': p.contentKind.name,
      'notes': p.notes,
      'lastWorkedAt': p.lastWorkedAt.toUtc().millisecondsSinceEpoch,
      'coverPageId': item.coverPageId,
      'grid': item.grid == null ? null : _grid(item.grid!, item.progress, item.cells),
      'book': item.book == null ? null : _book(item.book!),
      'workSessions': <Object?>[
        for (final WorkSession s in item.workSessions)
          <String, Object?>{
            'startedAt': s.startedAt.toUtc().millisecondsSinceEpoch,
            'endedAt': s.endedAt?.toUtc().millisecondsSinceEpoch,
          },
      ],
    };
  }

  static Map<String, Object?> _grid(GridPattern g, GridProgress? progress, CellProgress? cells) {
    final StoredGeometry geometry = GridGeometryCodec.encode(g.geometry);
    final GridLayersBlob? layers = g.layers;
    return <String, Object?>{
      'id': g.id,
      'geometry': <String, Object?>{'kind': geometry.kind, 'drop': geometry.drop},
      'metrics': jsonDecode(CellMetricsCodec.encode(g.metrics).valueOrNull!),
      'width': g.grid.width,
      'height': g.grid.height,
      'cells': base64Encode(GridCodec.encode(g.grid)),
      'palette': <Object?>[
        for (final PatternColor c in g.palette.colors)
          <String, Object?>{
            'rgb': (c.rgb.r << 16) | (c.rgb.g << 8) | c.rgb.b,
            'name': c.name,
            'components': <Object?>[
              for (final CatalogRef r in c.components) <String, String>{'brand': r.brand, 'code': r.code},
            ],
            'finish': c.finish,
            'symbol': c.symbol,
          },
      ],
      'layers': layers == null
          ? null
          : <String, Object?>{'codecVersion': layers.codecVersion, 'bytes': base64Encode(layers.bytes)},
      'progress': progress == null
          ? null
          : <String, Object?>{
              'completedRows': (progress.completedRows.toList()..sort()),
              'currentRow': progress.currentRow,
              'currentBead': progress.currentBead,
              if (cells != null && !cells.isEmpty)
                'cellBlocks': <String, Object?>{
                  for (final MapEntry<int, Uint8List> e in cells.blocks.entries) '${e.key}': base64Encode(e.value),
                },
            },
    };
  }

  static Map<String, Object?> _book(BiserBook b) => <String, Object?>{
    'id': b.patternId,
    'currentPageId': b.currentPageId,
    'pages': <Object?>[
      for (final BiserPage page in b.pages)
        <String, Object?>{
          'id': page.id,
          'file': page.file,
          'width': page.width,
          'height': page.height,
          'work': page.work == null
              ? null
              : <String, Object?>{
                  'top': page.work!.ruler.top,
                  'height': page.work!.ruler.height,
                  'step': page.work!.ruler.step,
                  'highlight': page.work!.ruler.highlight.name,
                  'row': page.work!.ruler.row,
                  'direction': page.work!.ruler.direction.name,
                  'zone': _zone(page.work!.ruler.zone),
                  'rowCount': page.work!.ruler.rowCount,
                  'scale': page.work!.viewport.scale,
                  'dx': page.work!.viewport.dx,
                  'dy': page.work!.viewport.dy,
                  // Необязательное поле T45: пометки маркером, версия формата прежняя.
                  if (!page.work!.markup.isEmpty) 'markup': base64Encode(PageMarkupCodec.encode(page.work!.markup)),
                },
        },
    ],
  };

  /// Разбирает манифест. [files] — файлы архива; страницы схем обязаны в нём быть.
  static Result<BiserBundle> decode(String manifest, Map<String, Uint8List> files) {
    try {
      return Success<BiserBundle>(_decode(manifest, files));
    } on _BadBiser catch (e) {
      return Err<BiserBundle>(ValidationFailure(e.message));
    }
  }

  static BiserBundle _decode(String manifest, Map<String, Uint8List> files) {
    final Object? parsed;
    try {
      parsed = jsonDecode(manifest);
    } on FormatException {
      throw const _BadBiser('Файл повреждён: манифест нечитаем');
    }
    final Map<String, Object?> root = _map(parsed, 'манифест');
    if (root['format'] != formatName) {
      throw const _BadBiser('Это не файл «Канители»');
    }
    final int version = _int(root['version'], 'версия формата');
    if (version > biserFormatVersion) {
      throw _BadBiser(
        'Файл создан более новой версией приложения (формат $version). Обновите «Канитель» и откройте файл снова.',
      );
    }
    if (version < 1) {
      throw _BadBiser('Неизвестная версия формата: $version');
    }
    final BiserKind kind = _enum(BiserKind.values, root['kind'], 'вид файла');
    final List<BiserProject> projects = <BiserProject>[];
    final Set<String> ids = <String>{};
    for (final Object? raw in _list(root['projects'], 'проекты')) {
      final BiserProject project = _readProject(_map(raw, 'проект'), files);
      if (!ids.add(project.project.id)) {
        throw _BadBiser('В файле дважды проект ${project.project.id}');
      }
      projects.add(project);
    }
    return BiserBundle(
      kind: kind,
      exportedAt: DateTime.fromMillisecondsSinceEpoch(_int(root['exportedAt'], 'время экспорта'), isUtc: true),
      appVersion: _string(root['appVersion'], 'версия приложения'),
      projects: projects,
      files: files,
      formatVersion: version,
    );
  }

  static BiserProject _readProject(Map<String, Object?> m, Map<String, Uint8List> files) {
    final String id = _id(m['id'], 'id проекта');
    final Craft craft = _enum(Craft.values, m['craft'], 'ремесло');
    final Technique technique = _enum(Technique.values, m['technique'], 'техника');
    if (technique.craft != craft) {
      throw const _BadBiser('Техника не подходит к ремеслу проекта');
    }
    final String name = _string(m['name'], 'название');
    final Project project = Project(
      id: id,
      name: name,
      status: _enum(ProjectStatus.values, m['status'], 'статус'),
      craft: craft,
      technique: technique,
      contentKind: _enum(ContentKind.values, m['contentKind'], 'вид содержимого'),
      notes: _string(m['notes'], 'заметки'),
      coverPath: null,
      lastWorkedAt: DateTime.fromMillisecondsSinceEpoch(_int(m['lastWorkedAt'], 'время работы'), isUtc: true),
    );
    GridPattern? grid;
    GridProgress? progress;
    CellProgress? cells;
    if (m['grid'] != null) {
      final Map<String, Object?> g = _map(m['grid'], 'схема');
      grid = _readGrid(g, id);
      final Map<String, Object?>? p = g['progress'] == null ? null : _map(g['progress'], 'прогресс');
      progress = p == null ? null : _readProgress(p, grid.grid);
      cells = p == null || p['cellBlocks'] == null ? null : _readCellBlocks(p['cellBlocks'], grid.grid);
    }
    BiserBook? book;
    if (m['book'] != null) {
      book = _readBook(_map(m['book'], 'схема из книги'), files);
    }
    if (grid != null && project.contentKind != ContentKind.grid) {
      throw const _BadBiser('Сетка есть у проекта другого вида');
    }
    if (book != null && project.contentKind != ContentKind.image) {
      throw const _BadBiser('Страницы книги есть у проекта другого вида');
    }
    final Object? cover = m['coverPageId'];
    String? coverPageId;
    if (cover != null) {
      coverPageId = _id(cover, 'обложка');
      if (book == null || !book.pages.any((p) => p.id == coverPageId)) {
        throw const _BadBiser('Обложка ссылается на несуществующую страницу');
      }
    }
    return BiserProject(
      project: project,
      grid: grid,
      progress: progress,
      cells: cells,
      book: book,
      coverPageId: coverPageId,
      workSessions: _readWorkSessions(m['workSessions'], id),
    );
  }

  /// Поля нет в файлах старше учёта времени: тогда сессий нет.
  static List<WorkSession> _readWorkSessions(Object? raw, String projectId) {
    if (raw == null) {
      return const <WorkSession>[];
    }
    if (raw is! List<Object?>) {
      throw const _BadBiser('Файл повреждён: сессии работы записаны неверно');
    }
    final List<WorkSession> sessions = <WorkSession>[];
    for (int i = 0; i < raw.length; i++) {
      final Map<String, Object?> s = _map(raw[i], 'сессия работы');
      final DateTime start = DateTime.fromMillisecondsSinceEpoch(_int(s['startedAt'], 'начало сессии'), isUtc: true);
      final Object? end = s['endedAt'];
      sessions.add(
        WorkSession(
          id: 'imported-$i',
          projectId: projectId,
          startedAt: start,
          endedAt: end == null ? null : DateTime.fromMillisecondsSinceEpoch(_int(end, 'конец сессии'), isUtc: true),
        ),
      );
    }
    return sessions;
  }

  static GridPattern _readGrid(Map<String, Object?> g, String projectId) {
    final Map<String, Object?> geo = _map(g['geometry'], 'геометрия');
    final GridGeometry geometry = _ok(
      GridGeometryCodec.decode(kind: _string(geo['kind'], 'геометрия'), drop: _int(geo['drop'], 'drop')),
    );
    final CellMetrics metrics = _ok(CellMetricsCodec.decode(jsonEncode(g['metrics'])));
    final Uint8List cellBytes;
    try {
      cellBytes = base64Decode(_string(g['cells'], 'сетка'));
    } on FormatException {
      throw const _BadBiser('Сетка записана неверно');
    }
    final Grid grid = _ok(GridCodec.decode(cellBytes));
    if (grid.width != _int(g['width'], 'ширина') || grid.height != _int(g['height'], 'высота')) {
      throw const _BadBiser('Размер сетки не совпадает с записью');
    }
    final List<PatternColor> colors = <PatternColor>[];
    for (final Object? raw in _list(g['palette'], 'палитра')) {
      final Map<String, Object?> c = _map(raw, 'цвет');
      final int rgb = _int(c['rgb'], 'цвет');
      if (rgb < 0 || rgb > 0xFFFFFF) {
        throw const _BadBiser('Цвет вне диапазона');
      }
      final List<CatalogRef> refs = <CatalogRef>[
        for (final Object? r in _list(c['components'], 'состав цвета'))
          CatalogRef(
            brand: _string(_map(r, 'позиция')['brand'], 'бренд'),
            code: _string(_map(r, 'позиция')['code'], 'код'),
          ),
      ];
      if (refs.isEmpty || refs.length > PatternColor.maxComponents) {
        throw const _BadBiser('Состав цвета записан неверно');
      }
      colors.add(
        PatternColor(
          rgb: Rgb((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF),
          name: _string(c['name'], 'название цвета'),
          components: refs,
          finish: _optString(c['finish'], 'отделка'),
          symbol: _optString(c['symbol'], 'символ'),
        ),
      );
    }
    if (grid.cells.any((v) => v > colors.length)) {
      throw const _BadBiser('В сетке есть цвет вне палитры');
    }
    GridLayersBlob? layers;
    if (g['layers'] != null) {
      final Map<String, Object?> l = _map(g['layers'], 'слои');
      try {
        layers = GridLayersBlob(
          codecVersion: _int(l['codecVersion'], 'версия слоёв'),
          bytes: base64Decode(_string(l['bytes'], 'слои')),
        );
      } on FormatException {
        throw const _BadBiser('Слои записаны неверно');
      }
    }
    return GridPattern(
      id: _id(g['id'], 'id схемы'),
      projectId: projectId,
      geometry: geometry,
      metrics: metrics,
      grid: grid,
      palette: PaletteSnapshot(colors),
      layers: layers,
    );
  }

  static GridProgress _readProgress(Map<String, Object?> p, Grid grid) {
    final Set<int> rows = <int>{};
    for (final Object? raw in _list(p['completedRows'], 'отмеченные ряды')) {
      final int row = _int(raw, 'ряд');
      if (row < 0 || row >= grid.height) {
        throw const _BadBiser('Отмеченный ряд вне схемы');
      }
      rows.add(row);
    }
    final int? row = p['currentRow'] == null ? null : _int(p['currentRow'], 'текущий ряд');
    final int? bead = p['currentBead'] == null ? null : _int(p['currentBead'], 'текущая бусина');
    if (row != null && (row < 0 || row >= grid.height)) {
      throw const _BadBiser('Текущий ряд вне схемы');
    }
    if (bead != null && (row == null || bead < 0 || bead >= grid.width)) {
      throw const _BadBiser('Текущая бусина вне схемы');
    }
    return GridProgress(completedRows: rows, currentRow: row, currentBead: bead);
  }

  static CellProgress _readCellBlocks(Object? raw, Grid grid) {
    final Map<String, Object?> m = _map(raw, 'отметки клеток');
    final int blocksPerRow = (grid.width + CellProgress.blockSide - 1) ~/ CellProgress.blockSide;
    final int blockRows = (grid.height + CellProgress.blockSide - 1) ~/ CellProgress.blockSide;
    final Map<int, Uint8List> blocks = <int, Uint8List>{};
    for (final MapEntry<String, Object?> e in m.entries) {
      final int? index = int.tryParse(e.key);
      if (index == null ||
          index < 0 ||
          index % CellProgress.blockStride >= blocksPerRow ||
          index ~/ CellProgress.blockStride >= blockRows) {
        throw const _BadBiser('Блок отметок вне схемы');
      }
      final Uint8List bytes;
      try {
        bytes = base64Decode(_string(e.value, 'блок отметок'));
      } on FormatException {
        throw const _BadBiser('Блок отметок записан неверно');
      }
      if (bytes.length != CellProgress.blockBytes) {
        throw const _BadBiser('Блок отметок записан неверно');
      }
      blocks[index] = bytes;
    }
    // Отметки за краем схемы (в неполном блоке) отбрасываем, а не считаем файл повреждённым.
    return CellProgress(width: grid.width, blocks: blocks).resized(newWidth: grid.width, newHeight: grid.height);
  }

  static BiserBook _readBook(Map<String, Object?> b, Map<String, Uint8List> files) {
    final List<BiserPage> pages = <BiserPage>[];
    final Set<String> ids = <String>{};
    for (final Object? raw in _list(b['pages'], 'страницы')) {
      final Map<String, Object?> m = _map(raw, 'страница');
      final String id = _id(m['id'], 'id страницы');
      if (!ids.add(id)) {
        throw const _BadBiser('Страница записана дважды');
      }
      final String file = _string(m['file'], 'файл страницы');
      final Uint8List? bytes = files[file];
      if (bytes == null) {
        throw _BadBiser('В архиве нет файла страницы $file');
      }
      if (bytes.length < _pngSignature.length || !_pngSignature.indexed.every((e) => bytes[e.$1] == e.$2)) {
        throw _BadBiser('Страница $file — не картинка PNG');
      }
      final int width = _int(m['width'], 'ширина страницы');
      final int height = _int(m['height'], 'высота страницы');
      if (width < 1 || height < 1) {
        throw const _BadBiser('Размер страницы должен быть положительным');
      }
      PageWork? work;
      if (m['work'] != null) {
        final Map<String, Object?> w = _map(m['work'], 'работа на странице');
        work = PageWork(
          pageId: id,
          ruler: RulerState(
            top: _double(w['top'], 'линейка'),
            height: _double(w['height'], 'линейка'),
            step: _double(w['step'], 'линейка'),
            highlight: _enum(RulerHighlight.values, w['highlight'], 'подсветка'),
            row: _int(w['row'], 'ряд линейки'),
            direction: _enum(RowDirection.values, w['direction'], 'направление рядов'),
            zone: _readZone(w['zone']),
            rowCount: _readRowCount(w['rowCount']),
          ),
          viewport: PageViewport(
            scale: _double(w['scale'], 'масштаб'),
            dx: _double(w['dx'], 'сдвиг'),
            dy: _double(w['dy'], 'сдвиг'),
          ),
          markup: _readMarkup(w['markup']),
        );
      }
      pages.add(BiserPage(id: id, file: file, width: width, height: height, work: work));
    }
    final String? current = b['currentPageId'] == null ? null : _id(b['currentPageId'], 'открытая страница');
    if (current != null && !ids.contains(current)) {
      throw const _BadBiser('Открытая страница не найдена');
    }
    return BiserBook(patternId: _id(b['id'], 'id схемы'), pages: pages, currentPageId: current);
  }

  static T _ok<T>(Result<T> result) => switch (result) {
    Success<T>(:final T value) => value,
    Err<T>(:final Failure failure) => throw _BadBiser(failure.message),
  };

  /// Пометки маркером: нет поля или оно не разбирается — страница без пометок, а не отказ импорта.
  static PageMarkup _readMarkup(Object? raw) {
    if (raw is! String) return const PageMarkup.empty();
    try {
      return PageMarkupCodec.decode(base64Decode(raw)) ?? const PageMarkup.empty();
    } on FormatException {
      return const PageMarkup.empty();
    }
  }

  static Map<String, Object?>? _zone(PatternZone? zone) => zone == null
      ? null
      : <String, Object?>{'top': zone.top, 'bottom': zone.bottom, 'left': zone.left, 'right': zone.right};

  /// Зона схемы на странице. В файлах без неё (`null` или ключа нет) схема занимает всю страницу.
  static PatternZone? _readZone(Object? v) {
    if (v == null) {
      return null;
    }
    final Map<String, Object?> z = _map(v, 'зона схемы');
    final PatternZone zone = PatternZone(
      top: _double(z['top'], 'зона схемы'),
      bottom: _double(z['bottom'], 'зона схемы'),
      left: _double(z['left'], 'зона схемы'),
      right: _double(z['right'], 'зона схемы'),
    );
    if (zone.top < 0 || zone.left < 0 || zone.height <= 0 || zone.width <= 0) {
      throw const _BadBiser('Файл повреждён: зона схемы записана неверно');
    }
    return zone;
  }

  static int? _readRowCount(Object? v) {
    if (v == null) {
      return null;
    }
    final int count = _int(v, 'число рядов');
    if (count < 1) {
      throw const _BadBiser('Файл повреждён: число рядов записано неверно');
    }
    return count;
  }

  static Map<String, Object?> _map(Object? v, String what) =>
      v is Map<String, Object?> ? v : throw _BadBiser('Файл повреждён: $what записан неверно');

  static List<Object?> _list(Object? v, String what) =>
      v is List<Object?> ? v : throw _BadBiser('Файл повреждён: $what записаны неверно');

  static String _string(Object? v, String what) =>
      v is String ? v : throw _BadBiser('Файл повреждён: $what записано неверно');

  static String? _optString(Object? v, String what) => v == null ? null : _string(v, what);

  static String _id(Object? v, String what) {
    final String s = _string(v, what);
    // id попадают в пути файлов: только безопасные символы, никаких «/» и «..».
    if (!_safeId.hasMatch(s)) {
      throw _BadBiser('Файл повреждён: $what записан неверно');
    }
    return s;
  }

  static int _int(Object? v, String what) => v is int ? v : throw _BadBiser('Файл повреждён: $what записано неверно');

  static double _double(Object? v, String what) {
    if (v is num && v.isFinite) {
      return v.toDouble();
    }
    throw _BadBiser('Файл повреждён: $what записано неверно');
  }

  static T _enum<T extends Enum>(List<T> values, Object? v, String what) {
    for (final T value in values) {
      if (value.name == v) {
        return value;
      }
    }
    throw _BadBiser('Неизвестное значение ($what): $v');
  }
}

final class _BadBiser implements Exception {
  const _BadBiser(this.message);

  final String message;
}
