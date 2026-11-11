import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/outline_backstitch.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';

const FakeCellMetrics _metrics = FakeCellMetrics(1, 1);
const int _scale = 3;

class _Scene {
  _Scene(this.grid, this.work, this.regions);

  final Grid grid;
  final WorkImage work;
  final CellRegions regions;
}

/// Схема [columns]×[rows], цвет клетки и значение сетки задают функции от клетки.
_Scene _scene(
  int columns,
  int rows, {
  required Rgb Function(int column, int row) color,
  required int Function(int column, int row) value,
}) {
  final int w = columns * _scale;
  final int h = rows * _scale;
  final Uint8List rgba = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final Rgb c = color(x ~/ _scale, y ~/ _scale);
      final int o = (y * w + x) * 4;
      rgba[o] = c.r;
      rgba[o + 1] = c.g;
      rgba[o + 2] = c.b;
      rgba[o + 3] = 255;
    }
  }
  final SourceImage image = SourceImage(width: w, height: h, rgba: rgba);
  const GridGeometry geometry = GridGeometry.rectangular();
  final WorkImage work = WorkImage.fromSource(
    image: image,
    geometry: geometry,
    metrics: _metrics,
    columns: columns,
    rows: rows,
    scale: _scale,
  );
  final CellRegions regions = CellRegions.forGrid(
    geometry: geometry,
    metrics: _metrics,
    columns: columns,
    rows: rows,
    imageWidth: work.width,
    imageHeight: work.height,
  );
  return _Scene(
    Grid.fromCells(
      width: columns,
      height: rows,
      cells: <int>[
        for (int r = 0; r < rows; r++)
          for (int c = 0; c < columns; c++) value(c, r),
      ],
    ),
    work,
    regions,
  );
}

const Rgb _black = Rgb(0, 0, 0);
const Rgb _white = Rgb(255, 255, 255);

List<LineStitch> _build(_Scene s, {Uint8List? subject, OutlineBackstitch stage = const OutlineBackstitch()}) =>
    stage.build(grid: s.grid, work: s.work, regions: s.regions, color: 1, subject: subject);

double _totalLength(List<LineStitch> lines) {
  double sum = 0;
  for (final LineStitch l in lines) {
    final int dx = l.to.x - l.from.x;
    final int dy = l.to.y - l.from.y;
    sum += math.sqrt((dx * dx + dy * dy).toDouble()) / 2;
  }
  return sum;
}

void main() {
  group('контраст', () {
    test('вертикальная граница чёрного и белого — линия по ней, стежки не длиннее maxStitch', () {
      final _Scene s = _scene(
        10,
        10,
        color: (c, r) => c < 5 ? _black : _white,
        value: (c, r) => c < 5 ? 1 : 2,
      );
      final List<LineStitch> lines = _build(s);
      expect(lines, isNotEmpty);
      for (final LineStitch l in lines) {
        expect(l.from.x, 10);
        expect(l.to.x, 10);
        expect(l.kind, LineKind.backstitch);
        expect(l.color, 1);
        expect((l.to.y - l.from.y) / 2, lessThanOrEqualTo(6));
      }
      expect(lines.first.from, const LatticeNode.corner(5, 0));
      expect(lines.last.to, const LatticeNode.corner(5, 10));
      expect(_totalLength(lines), 10);
    });

    test('границы с малым контрастом не получают линий', () {
      final _Scene s = _scene(
        10,
        10,
        color: (c, r) => c < 5 ? const Rgb(120, 120, 120) : const Rgb(128, 128, 128),
        value: (c, r) => c < 5 ? 1 : 2,
      );
      expect(_build(s), isEmpty);
    });

    test('если у клеток один цвет крестиков, контрастной линии нет', () {
      final _Scene s = _scene(10, 10, color: (c, r) => c < 5 ? _black : _white, value: (c, r) => 1);
      expect(_build(s), isEmpty);
    });

    test('короткие обрывки отбрасываются', () {
      // Одна клетка другого цвета посреди: контур из 4 клеток — дольше minLength 5 его нет.
      final _Scene s = _scene(
        10,
        10,
        color: (c, r) => c == 4 && r == 4 ? _black : _white,
        value: (c, r) => c == 4 && r == 4 ? 1 : 2,
      );
      expect(_build(s, stage: const OutlineBackstitch(minLength: 5)), isEmpty);
      expect(_build(s), isNotEmpty);
    });

    test('лесенка по диагонали упрощается в диагональные стежки', () {
      final _Scene s = _scene(
        12,
        12,
        color: (c, r) => c > r ? _black : _white,
        value: (c, r) => c > r ? 1 : 2,
      );
      final List<LineStitch> lines = _build(s);
      expect(lines, isNotEmpty);
      // Без упрощения было бы 22 единичных отрезка.
      expect(lines.length, lessThan(8));
      for (final LineStitch l in lines) {
        expect((l.to.y - l.from.y) / 2, lessThanOrEqualTo(6));
      }
    });
  });

  group('маска объекта', () {
    test('граница объекта обводится замкнутым контуром, даже без контраста', () {
      final _Scene s = _scene(10, 10, color: (c, r) => const Rgb(100, 100, 100), value: (c, r) => 1);
      final Uint8List subject = Uint8List(100);
      for (int r = 3; r < 7; r++) {
        for (int c = 3; c < 7; c++) {
          subject[r * 10 + c] = 1;
        }
      }
      final List<LineStitch> lines = _build(s, subject: subject);
      expect(_totalLength(lines), closeTo(16, 1e-9));
      expect(lines.length, 4);
      final Set<LatticeNode> corners = <LatticeNode>{
        for (final LineStitch l in lines) ...<LatticeNode>[l.from, l.to],
      };
      expect(corners, <LatticeNode>{
        const LatticeNode.corner(3, 3),
        const LatticeNode.corner(7, 3),
        const LatticeNode.corner(3, 7),
        const LatticeNode.corner(7, 7),
      });
    });

    test('объект у края картинки не обводится по краю схемы', () {
      final _Scene s = _scene(10, 10, color: (c, r) => const Rgb(100, 100, 100), value: (c, r) => 1);
      final Uint8List subject = Uint8List(100);
      for (int r = 0; r < 4; r++) {
        for (int c = 0; c < 4; c++) {
          subject[r * 10 + c] = 1;
        }
      }
      expect(_totalLength(_build(s, subject: subject)), closeTo(8, 1e-9));
    });

    test('маска неверного размера — ошибка', () {
      final _Scene s = _scene(10, 10, color: (c, r) => _white, value: (c, r) => 1);
      expect(() => _build(s, subject: Uint8List(5)), throwsArgumentError);
    });
  });

  group('общее', () {
    test('результат детерминирован и отсортирован', () {
      final _Scene s = _scene(10, 10, color: (c, r) => c < 5 ? _black : _white, value: (c, r) => c < 5 ? 1 : 2);
      final List<LineStitch> a = _build(s);
      expect(_build(s), a);
      final List<LineStitch> sorted = List<LineStitch>.of(a)..sort();
      expect(a, sorted);
    });

    test('все концы — углы клеток внутри схемы', () {
      final _Scene s = _scene(
        12,
        8,
        color: (c, r) => (c + r) % 3 == 0 ? _black : _white,
        value: (c, r) => (c + r) % 3 == 0 ? 1 : 2,
      );
      for (final LineStitch l in _build(s, stage: const OutlineBackstitch(minLength: 1))) {
        expect(l.from.isCorner && l.to.isCorner, isTrue);
        expect(l.to.x, lessThanOrEqualTo(24));
        expect(l.to.y, lessThanOrEqualTo(16));
      }
    });

    test('регионы не от этой сетки — ошибка', () {
      final _Scene a = _scene(10, 10, color: (c, r) => _white, value: (c, r) => 1);
      final _Scene b = _scene(8, 8, color: (c, r) => _white, value: (c, r) => 1);
      expect(
        () => const OutlineBackstitch().build(grid: a.grid, work: b.work, regions: b.regions, color: 1),
        throwsArgumentError,
      );
    });

    test('darkestUsedColor выбирает самый тёмный из используемых', () {
      final Grid grid = Grid.fromCells(width: 3, height: 1, cells: <int>[1, 3, 0]);
      const List<PaletteEntry> palette = <PaletteEntry>[
        PaletteEntry(rgb: Rgb(200, 200, 200)),
        PaletteEntry(rgb: Rgb(0, 0, 0)),
        PaletteEntry(rgb: Rgb(60, 60, 60)),
      ];
      expect(OutlineBackstitch.darkestUsedColor(grid, palette), 3);
      expect(OutlineBackstitch.darkestUsedColor(Grid.empty(width: 2, height: 2), palette), isNull);
    });
  });
}
