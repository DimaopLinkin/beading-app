import 'dart:typed_data';

import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';

const FakeCellMetrics _metrics = FakeCellMetrics(1, 1);
const int _size = 60;
const int _cells = 20;

/// Фон из пяти цветных полос, в центре красный круг (с чёрно-серой каймой для тёмного цвета в палитре).
SourceImage _scene() {
  const List<int> stripes = <int>[0x4060A0, 0x50A070, 0xC0B070, 0x8060A0, 0x60A0C0];
  final Uint8List bytes = Uint8List(_size * _size * 4);
  for (int y = 0; y < _size; y++) {
    for (int x = 0; x < _size; x++) {
      int color = stripes[x * 5 ~/ _size];
      final int dx = x - _size ~/ 2;
      final int dy = y - _size ~/ 2;
      if (dx * dx + dy * dy < 15 * 15) color = 0xD03030;
      final int o = (y * _size + x) * 4;
      bytes[o] = color >> 16 & 255;
      bytes[o + 1] = color >> 8 & 255;
      bytes[o + 2] = color & 255;
      bytes[o + 3] = 255;
    }
  }
  return SourceImage(width: _size, height: _size, rgba: bytes);
}

Uint8List _discMask() {
  final Uint8List mask = Uint8List(_size * _size);
  for (int y = 0; y < _size; y++) {
    for (int x = 0; x < _size; x++) {
      final int dx = x - _size ~/ 2;
      final int dy = y - _size ~/ 2;
      if (dx * dx + dy * dy < 15 * 15) mask[y * _size + x] = 255;
    }
  }
  return mask;
}

ImageToGridRequest _request({
  BackgroundMode background = BackgroundMode.keep,
  bool outline = false,
  Uint8List? mask,
  GridGeometry geometry = const GridGeometry.rectangular(),
  int maxColors = 8,
}) => ImageToGridRequest(
  image: _scene(),
  geometry: geometry,
  metrics: _metrics,
  columns: _cells,
  rows: _cells,
  maxColors: maxColors,
  paletteBuilder: const AccentPaletteBuilder(),
  labeler: const VotingCellLabeler(),
  subjectMask: mask,
  background: background,
  outline: outline,
);

Uint8List _subjectCells(GridGeometry geometry) => subjectCellsFrom(
  mask: _discMask(),
  imageWidth: _size,
  regions: CellRegions.forGrid(
    geometry: geometry,
    metrics: _metrics,
    columns: _cells,
    rows: _cells,
    imageWidth: _size,
    imageHeight: _size,
  ),
);

List<int> _values(GeneratedPattern p) => <int>[
  for (int i = 0; i < _cells * _cells; i++) p.grid.at(i % _cells, i ~/ _cells),
];

void main() {
  const ImageToGridPipeline pipeline = ImageToGridPipeline();

  test('«убрать» даёт 0 клеток фона и не трогает объект', () {
    final GeneratedPattern p = pipeline.run(_request(background: BackgroundMode.remove, mask: _discMask()));
    final Uint8List subject = _subjectCells(const GridGeometry.rectangular());
    final List<int> v = _values(p);
    expect(<int>[
      for (int i = 0; i < v.length; i++)
        if (subject[i] == 0 && v[i] != 0) i,
    ], isEmpty);
    expect(<int>[
      for (int i = 0; i < v.length; i++)
        if (subject[i] == 1 && v[i] == 0) i,
    ], isEmpty);
    expect(p.palette.length, lessThanOrEqualTo(8));
  });

  test('«упростить» оставляет вне маски не больше трёх цветов, «оставить» — больше', () {
    int bgColors(GeneratedPattern p) {
      final Uint8List subject = _subjectCells(const GridGeometry.rectangular());
      final List<int> v = _values(p);
      return <int>{
        for (int i = 0; i < v.length; i++)
          if (subject[i] == 0 && v[i] != 0) v[i],
      }.length;
    }

    final GeneratedPattern kept = pipeline.run(_request(mask: _discMask()));
    final GeneratedPattern simple = pipeline.run(_request(background: BackgroundMode.simplify, mask: _discMask()));
    expect(bgColors(kept), greaterThan(3));
    expect(bgColors(simple), inInclusiveRange(1, 3));
  });

  for (final GridGeometry geometry in <GridGeometry>[const GridGeometry.rectangular(), const GridGeometry.peyote()]) {
    test('обводка замкнута и шириной в одну клетку ($geometry)', () {
      final GeneratedPattern p = pipeline.run(_request(outline: true, mask: _discMask(), geometry: geometry));
      final Uint8List subject = _subjectCells(geometry);
      final CellNeighbors neighbors = CellNeighbors.of(geometry: geometry, columns: _cells, rows: _cells);
      final List<int> ring = BackgroundStage.outlineCells(subject, neighbors);
      final List<int> v = _values(p);
      expect(ring, isNotEmpty);
      final int dark = v[ring.first];
      // Все клетки кольца одного тёмного цвета.
      expect(ring.every((c) => v[c] == dark), isTrue);
      expect(Lab.fromRgb(p.palette[dark - 1].rgb).l, lessThan(35));
      // Внутри объекта этого цвета нет: кольцо в одну клетку.
      final Set<int> ringSet = ring.toSet();
      for (int c = 0; c < v.length; c++) {
        if (subject[c] == 1 && !ringSet.contains(c)) expect(v[c], isNot(dark), reason: 'клетка $c внутри обводки');
      }
      // Замкнута: ни одна клетка объекта не касается фона, не будучи обводкой.
      for (int c = 0; c < v.length; c++) {
        if (subject[c] != 1) continue;
        final bool touches = <int>[
          for (int n = 0; n < neighbors.count(c); n++) neighbors.at(c, n),
        ].any((o) => subject[o] == 0);
        expect(touches, ringSet.contains(c));
      }
    });
  }

  test('без маски фон и обводка не действуют', () {
    final GeneratedPattern a = pipeline.run(_request());
    final GeneratedPattern b = pipeline.run(_request(background: BackgroundMode.remove, outline: true));
    expect(_values(b), _values(a));
  });

  test('маска не того размера отвергается', () {
    expect(() => _request(mask: Uint8List(5)), throwsArgumentError);
  });

  test('настройки передают фон, обводку и маску в запрос', () {
    const ImageToGridSettings settings = ImageToGridSettings(background: BackgroundMode.remove, outline: true);
    final ImageToGridRequest request = settings.toRequest(image: _scene(), subjectMask: _discMask());
    expect(request.background, BackgroundMode.remove);
    expect(request.outline, isTrue);
    expect(request.usesBackgroundStage, isTrue);
  });

  test('результат детерминирован, фон на пейоте упрощается и убирается', () {
    for (final BackgroundMode mode in <BackgroundMode>[BackgroundMode.simplify, BackgroundMode.remove]) {
      final ImageToGridRequest r = _request(mask: _discMask(), background: mode, geometry: const GridGeometry.peyote());
      expect(_values(pipeline.run(r)), _values(pipeline.run(r)));
    }
    final GeneratedPattern removed = pipeline.run(
      _request(mask: _discMask(), background: BackgroundMode.remove, geometry: const GridGeometry.peyote()),
    );
    final Uint8List subject = _subjectCells(const GridGeometry.peyote());
    final List<int> v = _values(removed);
    expect(<int>[
      for (int i = 0; i < v.length; i++)
        if (subject[i] == 0 && v[i] != 0) i,
    ], isEmpty);
  });

  test('маска целиком объект: фон нечего менять, обводки нет', () {
    final Uint8List all = Uint8List(_size * _size)..fillRange(0, _size * _size, 255);
    final List<int> plain = _values(pipeline.run(_request()));
    final List<int> treated = _values(
      pipeline.run(_request(mask: all, background: BackgroundMode.remove, outline: true)),
    );
    expect(treated, plain);
  });

  test('пустая маска и «убрать»: все клетки пустые, не падает', () {
    final GeneratedPattern p = pipeline.run(
      _request(mask: Uint8List(_size * _size), background: BackgroundMode.remove),
    );
    expect(_values(p).every((v) => v == 0), isTrue);
  });

  test('effectiveImportance снижает вес фона', () {
    final Float32List keep = _request(mask: _discMask()).effectiveImportance ?? Float32List(0);
    expect(keep, isEmpty);
    final Float32List simplify = _request(mask: _discMask(), background: BackgroundMode.simplify).effectiveImportance!;
    final Float32List remove = _request(mask: _discMask(), background: BackgroundMode.remove).effectiveImportance!;
    expect(simplify[0], 0.5);
    expect(remove[0], closeTo(0.05, 1e-6));
    expect(simplify[_size * _size ~/ 2 + _size ~/ 2], 1);
  });

  test('обводки нет, если в палитре нет места и нет тёмного цвета', () {
    // Все цвета сцены светлее 45 по L, палитра заполнена: обводку не рисуем.
    final GeneratedPattern plain = pipeline.run(_request(mask: _discMask(), maxColors: 6));
    final GeneratedPattern outlined = pipeline.run(_request(mask: _discMask(), maxColors: 6, outline: true));
    final bool hasDark = plain.palette.any((e) => Lab.fromRgb(e.rgb).l <= 45);
    if (!hasDark && plain.palette.length >= 6) {
      expect(_values(outlined), _values(plain));
    } else {
      expect(outlined.palette.any((e) => Lab.fromRgb(e.rgb).l <= 45), isTrue);
    }
  });
}
