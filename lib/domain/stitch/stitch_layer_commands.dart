import 'dart:math' as math;

import 'package:beading/domain/editor/editor_commands.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';

/// Команды редактора для слоёв вышивки: чистые функции, исходные слои не меняются.
///
/// Записи за пределами схемы пропускаются (как у кисти в `EditorCommands`). Повторная запись с тем же ключом
/// заменяет прежнюю. Недопустимые значения отклоняют конструкторы стежков.
abstract final class StitchLayerCommands {
  /// Ставит неполный крестик; такой же по клетке, виду и ориентации заменяется.
  static StitchLayers addPartial(StitchLayers layers, PartialStitch stitch) {
    if (stitch.column >= layers.columns || stitch.row >= layers.rows) return layers;
    return layers.rebuilt(
      partials: <PartialStitch>[...layers.partials.where((p) => p.key != stitch.key), stitch],
    );
  }

  /// Убирает неполный крестик с таким ключом.
  static StitchLayers removePartial(
    StitchLayers layers,
    CellPosition cell,
    PartialKind kind,
    StitchOrientation orientation,
  ) {
    final List<PartialStitch> next = layers.partials
        .where((p) => p.key != (cell.column, cell.row, kind, orientation))
        .toList();
    return next.length == layers.partials.length ? layers : layers.rebuilt(partials: next);
  }

  /// Убирает все неполные крестики клетки.
  static StitchLayers clearCell(StitchLayers layers, CellPosition cell) {
    final List<PartialStitch> next = layers.partials
        .where((p) => p.column != cell.column || p.row != cell.row)
        .toList();
    return next.length == layers.partials.length ? layers : layers.rebuilt(partials: next);
  }

  /// Ставит линию; такая же между теми же узлами (в любом направлении) заменяется.
  static StitchLayers addLine(StitchLayers layers, LineStitch line) => addLines(layers, <LineStitch>[line]);

  /// Ставит много линий за один шаг: для контуров из картинки (T49) и импорта. Повторы заменяются, последний побеждает.
  static StitchLayers addLines(StitchLayers layers, Iterable<LineStitch> lines) {
    final Map<(LatticeNode, LatticeNode), LineStitch> byKey = <(LatticeNode, LatticeNode), LineStitch>{
      for (final LineStitch l in layers.lines) l.key: l,
    };
    bool changed = false;
    for (final LineStitch line in lines) {
      if (line.to.x > layers.columns * 2 || line.to.y > layers.rows * 2 || line.from.x > layers.columns * 2) continue;
      if (byKey[line.key] == line) continue;
      byKey[line.key] = line;
      changed = true;
    }
    return changed ? layers.rebuilt(lines: byKey.values) : layers;
  }

  /// Ломаная по узлам: отрезок между каждой соседней парой. Совпавшие подряд узлы пропускаются.
  static StitchLayers addLinePath(
    StitchLayers layers,
    List<LatticeNode> nodes, {
    required LineKind kind,
    required int color,
  }) {
    final List<LineStitch> lines = <LineStitch>[
      for (int i = 1; i < nodes.length; i++)
        if (nodes[i - 1] != nodes[i]) LineStitch(a: nodes[i - 1], b: nodes[i], kind: kind, color: color),
    ];
    return addLines(layers, lines);
  }

  /// Убирает линию между узлами (порядок концов не важен).
  static StitchLayers removeLine(StitchLayers layers, LatticeNode a, LatticeNode b) {
    final bool ordered = a.compareTo(b) < 0;
    final (LatticeNode, LatticeNode) key = ordered ? (a, b) : (b, a);
    final List<LineStitch> next = layers.lines.where((l) => l.key != key).toList();
    return next.length == layers.lines.length ? layers : layers.rebuilt(lines: next);
  }

  /// Ставит узелок или бусину; точка в том же узле заменяется.
  static StitchLayers addPoint(StitchLayers layers, PointStitch point) {
    if (point.node.x > layers.columns * 2 || point.node.y > layers.rows * 2) return layers;
    return layers.rebuilt(points: <PointStitch>[...layers.points.where((p) => p.node != point.node), point]);
  }

  /// Убирает точку в узле.
  static StitchLayers removePoint(StitchLayers layers, LatticeNode node) {
    final List<PointStitch> next = layers.points.where((p) => p.node != node).toList();
    return next.length == layers.points.length ? layers : layers.rebuilt(points: next);
  }

  /// Сложения по умолчанию.
  static StitchLayers setDefaultSpec(StitchLayers layers, StitchSpec spec) =>
      spec == layers.defaultSpec ? layers : layers.rebuilt(defaultSpec: spec);

  /// Своё число сложений для цвета; `null` снимает переопределение.
  static StitchLayers setColorSpec(StitchLayers layers, int color, StitchSpec? spec) {
    final Map<int, StitchSpec> next = Map<int, StitchSpec>.of(layers.colorSpecs);
    if (spec == null) {
      if (next.remove(color) == null) return layers;
    } else {
      if (next[color] == spec) return layers;
      next[color] = spec;
    }
    return layers.rebuilt(colorSpecs: next);
  }

  /// Переносит записи после правки палитры (удаление и слияние цветов): цвет `0` значит «цвета больше нет», запись
  /// удаляется. Стежки при смене цвета не сталкиваются (ключ без цвета); при слиянии двух цветов с разными
  /// сложениями остаются сложения цвета с меньшим номером.
  static StitchLayers reindexColors(StitchLayers layers, PaletteReindex reindex) {
    if (reindex.isIdentity) return layers;
    final Map<(int, int, PartialKind, StitchOrientation), PartialStitch> partials =
        <(int, int, PartialKind, StitchOrientation), PartialStitch>{};
    for (final PartialStitch p in layers.partials) {
      final int color = reindex.apply(p.color);
      if (color != 0) partials.putIfAbsent(p.key, () => p.copyWith(color: color));
    }
    final Map<(LatticeNode, LatticeNode), LineStitch> lines = <(LatticeNode, LatticeNode), LineStitch>{};
    for (final LineStitch l in layers.lines) {
      final int color = reindex.apply(l.color);
      if (color != 0) lines.putIfAbsent(l.key, () => LineStitch(a: l.from, b: l.to, kind: l.kind, color: color));
    }
    final List<PointStitch> points = <PointStitch>[];
    for (final PointStitch p in layers.points) {
      if (p.kind == PointKind.bead) {
        points.add(p);
        continue;
      }
      final int color = reindex.apply(p.color);
      if (color != 0) points.add(PointStitch.knot(node: p.node, kind: p.kind, color: color, wraps: p.wraps));
    }
    final Map<int, StitchSpec> specs = <int, StitchSpec>{};
    final List<int> specColors = layers.colorSpecs.keys.toList()..sort();
    for (final int color in specColors) {
      final int next = reindex.apply(color);
      if (next != 0) specs.putIfAbsent(next, () => layers.colorSpecs[color]!);
    }
    return layers.rebuilt(partials: partials.values, lines: lines.values, points: points, colorSpecs: specs);
  }

  /// Зеркало слоёв по горизонтали: стежки меняют сторону вместе с клетками.
  static StitchLayers mirrorHorizontal(StitchLayers layers) => layers.rebuilt(
    partials: layers.partials.map(
      (p) => PartialStitch(
        column: layers.columns - 1 - p.column,
        row: p.row,
        kind: p.kind,
        orientation: _flipHorizontal(p.orientation),
        color: p.color,
      ),
    ),
    lines: layers.lines.map(
      (l) => LineStitch(
        a: LatticeNode(layers.columns * 2 - l.from.x, l.from.y),
        b: LatticeNode(layers.columns * 2 - l.to.x, l.to.y),
        kind: l.kind,
        color: l.color,
      ),
    ),
    points: layers.points.map((p) => _movePoint(p, LatticeNode(layers.columns * 2 - p.node.x, p.node.y))),
  );

  /// Зеркало слоёв по вертикали.
  static StitchLayers mirrorVertical(StitchLayers layers) => layers.rebuilt(
    partials: layers.partials.map(
      (p) => PartialStitch(
        column: p.column,
        row: layers.rows - 1 - p.row,
        kind: p.kind,
        orientation: _flipVertical(p.orientation),
        color: p.color,
      ),
    ),
    lines: layers.lines.map(
      (l) => LineStitch(
        a: LatticeNode(l.from.x, layers.rows * 2 - l.from.y),
        b: LatticeNode(l.to.x, layers.rows * 2 - l.to.y),
        kind: l.kind,
        color: l.color,
      ),
    ),
    points: layers.points.map((p) => _movePoint(p, LatticeNode(p.node.x, layers.rows * 2 - p.node.y))),
  );

  /// Меняет размер вместе с сеткой (те же [width], [height] и [anchor], что у `EditorCommands.resize`): стежки
  /// сдвигаются (размер вне 1–4096 — [ArgumentError]: сначала проверяет сетка), не поместившиеся в новую схему (и линии, у которых вышел за край хотя бы один конец) удаляются.
  static StitchLayers resize(
    StitchLayers layers, {
    required int width,
    required int height,
    ResizeAnchor anchor = ResizeAnchor.topLeft,
  }) {
    final int dx = EditorCommands.anchorOffset(anchor, horizontal: true, from: layers.columns, to: width);
    final int dy = EditorCommands.anchorOffset(anchor, horizontal: false, from: layers.rows, to: height);
    bool inside(LatticeNode n) => n.x >= 0 && n.y >= 0 && n.x <= width * 2 && n.y <= height * 2;
    return StitchLayers(
      columns: width,
      rows: height,
      defaultSpec: layers.defaultSpec,
      colorSpecs: layers.colorSpecs,
      partials: <PartialStitch>[
        for (final PartialStitch p in layers.partials)
          if (p.column + dx >= 0 && p.column + dx < width && p.row + dy >= 0 && p.row + dy < height)
            p.copyWith(column: p.column + dx, row: p.row + dy),
      ],
      lines: <LineStitch>[
        for (final LineStitch l in layers.lines)
          if (_shiftedInside(l.from, dx, dy, inside) && _shiftedInside(l.to, dx, dy, inside))
            LineStitch(a: _shift(l.from, dx, dy), b: _shift(l.to, dx, dy), kind: l.kind, color: l.color),
      ],
      points: <PointStitch>[
        for (final PointStitch p in layers.points)
          if (_shiftedInside(p.node, dx, dy, inside)) _movePoint(p, _shift(p.node, dx, dy)),
      ],
    );
  }

  /// Убирает ближайший к точке ([x], [y] — в клетках от левого верхнего угла схемы) бэкстич или узелок не дальше
  /// [radius] клеток; линии выбираются раньше узелков, если обе в пределах радиуса — ближайшая. Нечего убирать —
  /// те же слои.
  static StitchLayers eraseNear(StitchLayers layers, double x, double y, {double radius = 0.35}) {
    LineStitch? bestLine;
    double bestLineDistance = radius;
    for (final LineStitch l in layers.lines) {
      final double d = _distanceToSegment(x, y, l.from.x / 2, l.from.y / 2, l.to.x / 2, l.to.y / 2);
      if (d <= bestLineDistance) {
        bestLine = l;
        bestLineDistance = d;
      }
    }
    PointStitch? bestPoint;
    double bestPointDistance = radius;
    for (final PointStitch p in layers.points) {
      final double d = math.sqrt(math.pow(x - p.node.x / 2, 2) + math.pow(y - p.node.y / 2, 2));
      if (d <= bestPointDistance) {
        bestPoint = p;
        bestPointDistance = d;
      }
    }
    if (bestLine != null && (bestPoint == null || bestLineDistance <= bestPointDistance)) {
      return removeLine(layers, bestLine.from, bestLine.to);
    }
    return bestPoint == null ? layers : removePoint(layers, bestPoint.node);
  }

  static double _distanceToSegment(double px, double py, double ax, double ay, double bx, double by) {
    final double dx = bx - ax;
    final double dy = by - ay;
    final double lengthSquared = dx * dx + dy * dy;
    final double t = lengthSquared == 0 ? 0 : (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
    return math.sqrt(math.pow(px - (ax + t * dx), 2) + math.pow(py - (ay + t * dy), 2));
  }

  /// Вставляет пустой ряд перед рядом [at] (`at == rows` — в конец): стежки ниже сдвигаются вниз. Линия, один конец
  /// которой выше вставки, а другой ниже, растягивается на новый ряд.
  static StitchLayers insertRow(StitchLayers layers, int at) =>
      _remap(layers, rows: layers.rows + 1, mapY: (y) => y >= at * 2 ? y + 2 : y, mapRow: (r) => r >= at ? r + 1 : r);

  /// Вставляет пустой столбец перед столбцом [at] (`at == columns` — в конец).
  static StitchLayers insertColumn(StitchLayers layers, int at) => _remap(
    layers,
    columns: layers.columns + 1,
    mapX: (x) => x >= at * 2 ? x + 2 : x,
    mapColumn: (c) => c >= at ? c + 1 : c,
  );

  /// Удаляет ряд [at] вместе со стежками в нём; линии и узелки, чьи узлы лежат внутри ряда, удаляются, узлы на его
  /// нижней границе сливаются с верхней.
  static StitchLayers deleteRow(StitchLayers layers, int at) => _remap(
    layers,
    rows: layers.rows - 1,
    mapY: (y) => y <= at * 2 ? y : (y >= (at + 1) * 2 ? y - 2 : null),
    mapRow: (r) => r == at ? null : (r > at ? r - 1 : r),
  );

  /// Удаляет столбец [at] вместе со стежками в нём.
  static StitchLayers deleteColumn(StitchLayers layers, int at) => _remap(
    layers,
    columns: layers.columns - 1,
    mapX: (x) => x <= at * 2 ? x : (x >= (at + 1) * 2 ? x - 2 : null),
    mapColumn: (c) => c == at ? null : (c > at ? c - 1 : c),
  );

  /// Переносит записи после вставки или удаления ряда или столбца. `null` из функции — запись пропадает; линия,
  /// ставшая точкой, тоже.
  static StitchLayers _remap(
    StitchLayers layers, {
    int? columns,
    int? rows,
    int? Function(int x)? mapX,
    int? Function(int y)? mapY,
    int? Function(int column)? mapColumn,
    int? Function(int row)? mapRow,
  }) {
    LatticeNode? node(LatticeNode n) {
      final int? x = mapX == null ? n.x : mapX(n.x);
      final int? y = mapY == null ? n.y : mapY(n.y);
      return x == null || y == null ? null : LatticeNode(x, y);
    }

    final List<PartialStitch> partials = <PartialStitch>[];
    for (final PartialStitch p in layers.partials) {
      final int? column = mapColumn == null ? p.column : mapColumn(p.column);
      final int? row = mapRow == null ? p.row : mapRow(p.row);
      if (column != null && row != null) partials.add(p.copyWith(column: column, row: row));
    }
    final List<LineStitch> lines = <LineStitch>[];
    for (final LineStitch l in layers.lines) {
      final LatticeNode? a = node(l.from);
      final LatticeNode? b = node(l.to);
      if (a != null && b != null && a != b) lines.add(LineStitch(a: a, b: b, kind: l.kind, color: l.color));
    }
    final List<PointStitch> points = <PointStitch>[];
    for (final PointStitch p in layers.points) {
      final LatticeNode? moved = node(p.node);
      if (moved != null) points.add(_movePoint(p, moved));
    }
    return StitchLayers(
      columns: columns ?? layers.columns,
      rows: rows ?? layers.rows,
      defaultSpec: layers.defaultSpec,
      colorSpecs: layers.colorSpecs,
      partials: partials,
      lines: lines,
      points: points,
    );
  }

  static LatticeNode _shift(LatticeNode n, int dx, int dy) => LatticeNode(n.x + dx * 2, n.y + dy * 2);

  static bool _shiftedInside(LatticeNode n, int dx, int dy, bool Function(LatticeNode) inside) {
    final int x = n.x + dx * 2;
    final int y = n.y + dy * 2;
    return x >= 0 && y >= 0 && inside(LatticeNode(x, y));
  }

  static PointStitch _movePoint(PointStitch p, LatticeNode node) => p.kind == PointKind.bead
      ? PointStitch.bead(node: node, bead: p.bead!)
      : PointStitch.knot(node: node, kind: p.kind, color: p.color, wraps: p.wraps);

  static StitchOrientation _flipHorizontal(StitchOrientation o) => switch (o) {
    StitchOrientation.topLeft => StitchOrientation.topRight,
    StitchOrientation.topRight => StitchOrientation.topLeft,
    StitchOrientation.bottomLeft => StitchOrientation.bottomRight,
    StitchOrientation.bottomRight => StitchOrientation.bottomLeft,
    StitchOrientation.slash => StitchOrientation.backslash,
    StitchOrientation.backslash => StitchOrientation.slash,
  };

  static StitchOrientation _flipVertical(StitchOrientation o) => switch (o) {
    StitchOrientation.topLeft => StitchOrientation.bottomLeft,
    StitchOrientation.bottomLeft => StitchOrientation.topLeft,
    StitchOrientation.topRight => StitchOrientation.bottomRight,
    StitchOrientation.bottomRight => StitchOrientation.topRight,
    StitchOrientation.slash => StitchOrientation.backslash,
    StitchOrientation.backslash => StitchOrientation.slash,
  };
}
