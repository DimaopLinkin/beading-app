import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/cleanup_steps.dart';
import 'package:beading/domain/image_to_grid/face_guide.dart';
import 'package:beading/domain/image_to_grid/face_step.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/label_smoother.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';
import 'image_fixtures.dart';

/// Восемь цветов палитры: красный, зелёный, синий, белый, чёрный и три серых.
const List<int> _paletteRgb = <int>[
  0xE02020,
  0x20C020,
  0x2020E0,
  0xF0F0F0,
  0x101010,
  0x808080,
  0xA0A0A0,
  0x606060,
];

List<Lab> get _palette => <Lab>[
  for (final int c in _paletteRgb) Lab.fromRgb(Rgb((c >> 16) & 255, (c >> 8) & 255, c & 255)),
];

/// Рабочая картинка 4 × 4 клетки по 3 пикселя: левая половина красная, правая синяя; клетка (1, 1) — 6 пикселей красных
/// и 3 синих (граница 2/3 : 1/3).
WorkImage _work() {
  final SourceImage image = blockImage(<List<int>>[
    <int>[0xE02020, 0xE02020, 0x2020E0, 0x2020E0],
    <int>[0xE02020, 0xE02020, 0x2020E0, 0x2020E0],
    <int>[0xE02020, 0xE02020, 0x2020E0, 0x2020E0],
    <int>[0xE02020, 0xE02020, 0x2020E0, 0x2020E0],
  ], block: 3);
  // Клетка (1, 1): правый столбец пикселей синий.
  final Uint8List rgba = image.rgba;
  for (int y = 3; y < 6; y++) {
    final int o = (y * 12 + 5) * 4;
    rgba[o] = 0x20;
    rgba[o + 1] = 0x20;
    rgba[o + 2] = 0xE0;
  }
  return WorkImage.fromSource(
    image: SourceImage(width: 12, height: 12, rgba: rgba),
    geometry: const GridGeometry.rectangular(),
    metrics: const FakeCellMetrics(1, 1),
    columns: 4,
    rows: 4,
    scale: 3,
  );
}

CellRegions _regions() => CellRegions.forGrid(
  geometry: const GridGeometry.rectangular(),
  metrics: const FakeCellMetrics(1, 1),
  columns: 4,
  rows: 4,
  imageWidth: 12,
  imageHeight: 12,
);

void main() {
  group('CellCosts: разреженная таблица', () {
    // 2 клетки, 5 цветов, 2 кандидата на клетку.
    final List<Lab> palette = <Lab>[
      for (final int g in <int>[0, 25, 50, 75, 100]) Lab(g.toDouble(), 0, 0),
    ];
    CellCosts build() => CellCosts.sparse(
      columns: 2,
      rows: 1,
      colorCount: 5,
      slots: 2,
      candidates: Uint16List.fromList(<int>[1, 2, 4, 3]),
      candidateCosts: Float32List.fromList(<double>[3, 1, 6, 7]),
      candidateCounts: Uint8List.fromList(<int>[2, 2]),
      mean: Float32List.fromList(<double>[40, 0, 0, 80, 0, 0]),
      spread: Float32List.fromList(<double>[5, -1]),
      palette: palette,
    );

    test('кандидат отдаёт точную цену, остальные — расстояние до среднего плюс разброс', () {
      final CellCosts costs = build();
      expect(costs.isSparse, isTrue);
      expect(costs.at(0, 1), 3);
      expect(costs.at(0, 2), 1);
      expect(costs.at(0, 0), closeTo(40 + 5, 1e-9));
      expect(costs.at(0, 4), closeTo(60 + 5, 1e-9));
    });

    test('пустая клетка: все цены 0', () {
      final CellCosts costs = build();
      for (int c = 0; c < 5; c++) {
        expect(costs.at(1, c), 0);
      }
      expect(costs.cheapest(1), 0);
    });

    test('cheapest берёт самого дешёвого кандидата, при равенстве — меньший номер', () {
      expect(build().cheapest(0), 2);
      final CellCosts tie = CellCosts.sparse(
        columns: 1,
        rows: 1,
        colorCount: 5,
        slots: 2,
        candidates: Uint16List.fromList(<int>[4, 2]),
        candidateCosts: Float32List.fromList(<double>[1, 1]),
        candidateCounts: Uint8List.fromList(<int>[2]),
        mean: Float32List.fromList(<double>[50, 0, 0]),
        spread: Float32List.fromList(<double>[1]),
        palette: palette,
      );
      expect(tie.cheapest(0), 2);
    });

    test('кандидаты перебираются по номеру клетки', () {
      final CellCosts costs = build();
      expect(costs.candidateCount(0), 2);
      expect(<int>[costs.candidateAt(0, 0), costs.candidateAt(0, 1)], <int>[1, 2]);
    });

    test('select: цвета переименовываются, убранные отбрасываются, палитра переставляется', () {
      final CellCosts costs = build().select(<int>[2, 1, 0]);
      expect(costs.isSparse, isTrue);
      expect(costs.colorCount, 3);
      expect(costs.candidateCount(0), 2);
      expect(costs.at(0, 0), 1); // был цвет 2
      expect(costs.at(0, 1), 3); // был цвет 1
      expect(costs.cheapest(0), 0);
      // Цвет 0 не кандидат: оценка по среднему 40 и палитре (Lab 0 → расстояние 40).
      expect(costs.at(0, 2), closeTo(45, 1e-9));
    });

    test('select: клетка без кандидатов оценивается по среднему цвету', () {
      final CellCosts costs = build().select(<int>[0, 3]);
      expect(costs.candidateCount(0), 0);
      expect(costs.candidateCount(1), 1);
      // Средний Lab клетки 0 — L 40; цвет 3 (L 75) дальше, чем цвет 0 (L 0)? 35 против 40: ближе цвет 1 новой палитры.
      expect(costs.cheapest(0), 1);
      expect(costs.at(0, 1), closeTo(35 + 5, 1e-9));
    });

    test('плотная таблица: isSparse ложно, кандидаты — все цвета', () {
      final CellCosts dense = CellCosts(
        columns: 1,
        rows: 1,
        colorCount: 3,
        values: Float32List.fromList(<double>[3, 1, 2]),
      );
      expect(dense.isSparse, isFalse);
      expect(dense.candidateCount(0), 3);
      expect(dense.candidateAt(0, 2), 2);
      expect(dense.cheapest(0), 1);
    });
  });

  group('Разметчики на разреженном пути', () {
    for (final (String name, CellLabeler dense, CellLabeler sparse) in <(String, CellLabeler, CellLabeler)>[
      ('VotingCellLabeler', const VotingCellLabeler(), const VotingCellLabeler(denseBudget: 50)),
      ('DetailCellLabeler', const DetailCellLabeler(), const DetailCellLabeler(denseBudget: 50)),
    ]) {
      group(name, () {
        final WorkImage work = _work();
        final CellRegions regions = _regions();
        final LabeledCells exact = dense.label(work: work, regions: regions, palette: _palette);
        final LabeledCells approx = sparse.label(work: work, regions: regions, palette: _palette);

        test('бюджет не превышен — путь плотный, превышен — разреженный', () {
          expect(exact.costs.isSparse, isFalse);
          expect(approx.costs.isSparse, isTrue);
          expect(approx.costs.candidateCount(0), 4);
        });

        test('цвета клеток те же, что у плотного пути, граница берёт цвет большей части', () {
          expect(approx.values, exact.values);
          expect(approx.values[5], 1); // клетка (1, 1): красного 2/3 — красный цвет палитры
        });

        test('цены кандидатов точные', () {
          for (int cell = 0; cell < 16; cell++) {
            for (int i = 0; i < approx.costs.candidateCount(cell); i++) {
              final int c = approx.costs.candidateAt(cell, i);
              expect(approx.costs.at(cell, c), closeTo(exact.costs.at(cell, c), 1e-3), reason: 'клетка $cell цвет $c');
            }
          }
        });

        test('цена не-кандидата — оценка сверху, не дешевле кандидата-победителя', () {
          for (int cell = 0; cell < 16; cell++) {
            final double best = approx.costs.at(cell, approx.values[cell] - 1);
            for (int c = 0; c < 8; c++) {
              expect(approx.costs.at(cell, c), greaterThanOrEqualTo(exact.costs.at(cell, c) - 1e-3));
              expect(approx.costs.at(cell, c), greaterThanOrEqualTo(best - 1e-9));
            }
          }
        });

        test('прозрачная клетка пуста, цены 0', () {
          final SourceImage clear = blockImage(
            <List<int>>[
              <int>[0xE02020, 0xE02020, 0xE02020, 0xE02020],
            ],
            block: 3,
            alpha: 0,
          );
          final WorkImage transparent = WorkImage.fromSource(
            image: clear,
            geometry: const GridGeometry.rectangular(),
            metrics: const FakeCellMetrics(1, 1),
            columns: 4,
            rows: 1,
            scale: 3,
          );
          final LabeledCells out = sparse.label(
            work: transparent,
            regions: CellRegions.forGrid(
              geometry: const GridGeometry.rectangular(),
              metrics: const FakeCellMetrics(1, 1),
              columns: 4,
              rows: 1,
              imageWidth: 12,
              imageHeight: 3,
            ),
            palette: _palette,
          );
          expect(out.values, everyElement(0));
          expect(out.costs.at(0, 3), 0);
        });
      });
    }

    test('DetailCellLabeler считает заметность и на разреженном пути', () {
      final LabeledCells out = const DetailCellLabeler(denseBudget: 50).label(
        work: _work(),
        regions: _regions(),
        palette: _palette,
      );
      expect(out.detail, isNotNull);
      expect(out.detail, hasLength(16));
    });
  });

  group('PottsLabelSmoother на разреженных ценах', () {
    test('клетка с красным меньшинством среди красных соседей перекрашивается, как на плотных ценах', () {
      // Поле 5 × 5 красных клеток (цвет 1) с одним зелёным пикселем-клеткой посередине (цвет 2).
      final List<List<int>> blocks = <List<int>>[
        for (int y = 0; y < 5; y++) <int>[for (int x = 0; x < 5; x++) x == 2 && y == 2 ? 0x30B030 : 0xE02020],
      ];
      final SourceImage image = blockImage(blocks, block: 3);
      // Средняя клетка: 4 красных пикселя из 9, остальные зелёные.
      for (final int i in <int>[0, 1, 2, 3]) {
        final int o = ((6 + i ~/ 3) * 15 + 6 + i % 3) * 4;
        image.rgba[o] = 0xE0;
        image.rgba[o + 1] = 0x20;
        image.rgba[o + 2] = 0x20;
      }
      final WorkImage work = WorkImage.fromSource(
        image: image,
        geometry: const GridGeometry.rectangular(),
        metrics: const FakeCellMetrics(1, 1),
        columns: 5,
        rows: 5,
        scale: 3,
      );
      final CellRegions regions = CellRegions.forGrid(
        geometry: const GridGeometry.rectangular(),
        metrics: const FakeCellMetrics(1, 1),
        columns: 5,
        rows: 5,
        imageWidth: 15,
        imageHeight: 15,
      );
      final CellNeighbors neighbors = CellNeighbors.of(
        geometry: const GridGeometry.rectangular(),
        columns: 5,
        rows: 5,
      );
      Uint16List run(CellLabeler labeler) {
        final LabeledCells labeled = labeler.label(work: work, regions: regions, palette: _palette);
        return const PottsLabelSmoother(detail: 0).smooth(
          values: Uint16List.fromList(labeled.values),
          costs: labeled.costs,
          neighbors: neighbors,
          importance: Float32List(25)..fillRange(0, 25, 1),
          edges: Float32List(25),
        );
      }

      final Uint16List sparse = run(const VotingCellLabeler(denseBudget: 100));
      expect(run(const VotingCellLabeler()), everyElement(1));
      expect(sparse, everyElement(1));
    });
  });

  group('Конвейер с разреженной таблицей', () {
    test('сглаживание, очистка и шаг лица выполняются без ошибок', () {
      final SourceImage image = blockImage(<List<int>>[
        for (int y = 0; y < 8; y++)
          <int>[for (int x = 0; x < 8; x++) x < 4 ? 0xE02020 : (y == 3 ? 0x30B030 : 0x2020E0)],
      ], block: 6);
      final GeneratedPattern pattern = const ImageToGridPipeline().run(
        ImageToGridRequest(
          image: image,
          geometry: const GridGeometry.rectangular(),
          metrics: const FakeCellMetrics(1, 1),
          columns: 8,
          rows: 8,
          maxColors: 8,
          constraint: PaletteConstraint.list(<PaletteEntry>[
            for (final int c in _paletteRgb) PaletteEntry(rgb: Rgb(c >> 16, (c >> 8) & 255, c & 255)),
          ]),
          paletteBuilder: const AccentPaletteBuilder(),
          labeler: const VotingCellLabeler(denseBudget: 100),
          smoother: const PottsLabelSmoother(),
          steps: const <PatternStep>[RemoveIslandsStep(), MergeColorsStep(), FaceFeatureStep()],
        ),
      );
      expect(pattern.grid.width, 8);
      expect(pattern.grid.at(0, 0), isNot(pattern.grid.at(7, 0)));
      expect(pattern.palette, isNotEmpty);
    });

    test('FaceFeatureStep работает с разреженными ценами', () {
      final LabeledCells labeled = const VotingCellLabeler(
        denseBudget: 10,
      ).label(work: _work(), regions: _regions(), palette: _palette);
      expect(labeled.costs.isSparse, isTrue);
      final GeneratedPattern pattern = GeneratedPattern(
        grid: Grid.fromCells(width: 4, height: 4, cells: <int>[for (int i = 0; i < 16; i++) labeled.values[i]]),
        palette: <PaletteEntry>[
          for (final int c in _paletteRgb) PaletteEntry(rgb: Rgb(c >> 16, (c >> 8) & 255, c & 255)),
        ],
      );
      final PatternStepContext context = PatternStepContext(
        geometry: const GridGeometry.rectangular(),
        cellImportance: Float32List(16)..fillRange(0, 16, 1),
        costs: labeled.costs,
        faces: FaceCells(
          columns: 4,
          rows: 4,
          skin: Uint8List.fromList(<int>[for (int i = 0; i < 16; i++) i < 8 ? 1 : 0]),
          feature: Uint8List(16),
          pupils: const <int>[],
          lips: const <int>[],
        ),
      );
      final GeneratedPattern out = const FaceFeatureStep().apply(pattern, context);
      expect(out.grid.width, 4);
    });
  });
}
