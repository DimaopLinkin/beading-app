import 'dart:typed_data';

import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/blend_suggester.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/frame_planner.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_frame.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';
import 'image_fixtures.dart';

void main() {
  const FakeCellMetrics square = FakeCellMetrics(1, 1);

  group('GridSizing.rowsForAspect', () {
    test('rowsForColumns равен rowsForAspect по аспекту картинки', () {
      for (final GridGeometry g in <GridGeometry>[
        const GridGeometry.rectangular(),
        const GridGeometry.peyote(),
        const GridGeometry.brick(),
      ]) {
        expect(
          GridSizing.rowsForColumns(imageWidth: 300, imageHeight: 200, geometry: g, metrics: square, columns: 30),
          GridSizing.rowsForAspect(aspect: 1.5, geometry: g, metrics: square, columns: 30),
        );
      }
    });

    test('прямоугольная сетка, пейот и кирпичный стежок', () {
      expect(
        GridSizing.rowsForAspect(
          aspect: 2,
          geometry: const GridGeometry.rectangular(),
          metrics: square,
          columns: 20,
        ),
        10,
      );
      // Пейот добавляет полклетки к высоте: 20 × 10,5 при аспекте 2 даёт ближайшие 10 рядов.
      expect(
        GridSizing.rowsForAspect(aspect: 2, geometry: const GridGeometry.peyote(), metrics: square, columns: 20),
        inInclusiveRange(9, 10),
      );
      // Кирпич повёрнут: ячейка в нём меняет стороны, на ровной бусине ряды считаются по обратной стороне.
      expect(
        GridSizing.rowsForAspect(
          aspect: 1,
          geometry: const GridGeometry.brick(),
          metrics: const FakeCellMetrics(2, 1),
          columns: 10,
        ),
        inInclusiveRange(4, 6),
      );
    });

    test('columnsForAspect обратна rowsForAspect', () {
      const GridGeometry g = GridGeometry.rectangular();
      final int rows = GridSizing.rowsForAspect(aspect: 0.5, geometry: g, metrics: square, columns: 10);
      expect(GridSizing.columnsForAspect(aspect: 0.5, geometry: g, metrics: square, rows: rows), 10);
    });
  });

  group('ImageToGridSettings: высота', () {
    test('rows по умолчанию null, ограничение и clearRows', () {
      const ImageToGridSettings s = ImageToGridSettings();
      expect(s.rows, isNull);
      expect(s.fit, FrameFit.crop);
      expect(s.copyWith(rows: 30).rows, 30);
      expect(s.copyWith(rows: 30).copyWith(columns: 50).rows, 30);
      expect(s.copyWith(rows: 30).copyWith(clearRows: true).rows, isNull);
      expect(s.copyWith(rows: 99999).rows, Grid.maxSide);
      expect(s.copyWith(rows: 0).rows, 1);
    });

    test('вышивка: потолок высоты 200 см', () {
      final ImageToGridSettings s = const ImageToGridSettings(technique: Technique.crossStitch).copyWith(rows: 99999);
      expect(s.rows, Fabric.standard.cellsForCm(ImageToGridSettings.maxStitchHeightCm));
      expect(s.heightCm, closeTo(200, 0.5));
    });

    test('смена канвы сохраняет высоту в сантиметрах', () {
      final ImageToGridSettings s = const ImageToGridSettings(technique: Technique.crossStitch).copyWith(rows: 140);
      final Fabric fine = Fabric.create(kind: FabricKind.aida, count: 18).valueOrNull!;
      final ImageToGridSettings next = s.withFabric(fine);
      expect(next.rows, fine.cellsForCm(ImageToGridSettings.snapCm(s.heightCm)));
      expect(const ImageToGridSettings(technique: Technique.crossStitch).withFabric(fine).rows, isNull);
    });
  });

  group('FramePlanner', () {
    const ImageToGridSettings base = ImageToGridSettings();

    test('высота по фото: рамка и сетка как раньше, без смещения', () {
      final FramePlan plan = FramePlanner.plan(
        sourceWidth: 400,
        sourceHeight: 300,
        crop: CropRect.full,
        settings: base,
      );
      expect(plan.effectiveCrop, CropRect.full);
      expect(plan.innerColumns, 40);
      expect(plan.innerRows, base.effectiveRows(SourceImage(width: 400, height: 300, rgba: Uint8List(400 * 300 * 4))));
      expect(plan.offsetColumn, 0);
      expect(plan.offsetRow, 0);
      expect(plan.hasMargins, isFalse);
    });

    test('crop: рамка подгоняется под размер, сетка без смещения', () {
      final ImageToGridSettings s = base.copyWith(rows: 40); // для станка ячейка не квадратная
      final FramePlan plan = FramePlanner.plan(
        sourceWidth: 400,
        sourceHeight: 300,
        crop: CropRect.full,
        settings: s,
      );
      expect((plan.innerColumns, plan.innerRows), (40, 40));
      final double target =
          s.geometry.extent(s.metrics, columns: 40, rows: 40).width /
          s.geometry.extent(s.metrics, columns: 40, rows: 40).height;
      expect(plan.effectiveCrop.width * (400 / 300) / plan.effectiveCrop.height, closeTo(target, 1e-9));
      expect((plan.offsetColumn, plan.offsetRow), (0, 0));
    });

    test('margins: широкое фото в высокой сетке — поля сверху и снизу', () {
      final ImageToGridSettings s = const ImageToGridSettings(
        technique: Technique.crossStitch,
        columns: 60,
      ).copyWith(rows: 100, fit: FrameFit.margins);
      final FramePlan plan = FramePlanner.plan(
        sourceWidth: 600,
        sourceHeight: 300,
        crop: CropRect.full,
        settings: s,
      );
      expect(plan.effectiveCrop, CropRect.full);
      expect(plan.innerColumns, 60);
      expect(plan.innerRows, inInclusiveRange(29, 31));
      expect(plan.offsetColumn, 0);
      expect(plan.offsetRow, (100 - plan.innerRows) ~/ 2);
      expect((plan.columns, plan.rows), (60, 100));
    });

    test('margins: высокое фото в широкой сетке — поля слева и справа', () {
      final ImageToGridSettings s = const ImageToGridSettings(
        technique: Technique.crossStitch,
        columns: 100,
      ).copyWith(rows: 60, fit: FrameFit.margins);
      final FramePlan plan = FramePlanner.plan(
        sourceWidth: 300,
        sourceHeight: 600,
        crop: CropRect.full,
        settings: s,
      );
      expect(plan.innerRows, 60);
      expect(plan.innerColumns, inInclusiveRange(29, 31));
      expect(plan.offsetColumn, (100 - plan.innerColumns) ~/ 2);
    });

    test('margins: rows больше и меньше авто', () {
      final ImageToGridSettings wide = const ImageToGridSettings(
        technique: Technique.crossStitch,
        columns: 60,
      ).copyWith(fit: FrameFit.margins);
      // Фото 3:2 при 60 столбцах — авто 40 рядов.
      final FramePlan taller = FramePlanner.plan(
        sourceWidth: 300,
        sourceHeight: 200,
        crop: CropRect.full,
        settings: wide.copyWith(rows: 80),
      );
      expect((taller.innerColumns, taller.innerRows), (60, 40));
      expect(taller.offsetRow, 20);
      final FramePlan shorter = FramePlanner.plan(
        sourceWidth: 300,
        sourceHeight: 200,
        crop: CropRect.full,
        settings: wide.copyWith(rows: 20),
      );
      expect(shorter.innerRows, 20);
      expect(shorter.innerColumns, 30);
      expect(shorter.offsetColumn, 15);
    });

    test('margins: полная сетка не больше Grid.maxSide', () {
      // Конструктор не ограничивает высоту: планировщик сам не выходит за Grid.maxSide.
      const ImageToGridSettings s = ImageToGridSettings(
        columns: 100,
        rows: 9000,
        fit: FrameFit.margins,
      );
      final FramePlan plan = FramePlanner.plan(
        sourceWidth: 300,
        sourceHeight: 200,
        crop: CropRect.full,
        settings: s,
      );
      expect(plan.rows, Grid.maxSide);
      expect(plan.innerRows, lessThanOrEqualTo(Grid.maxSide));
    });

    test('peyote: смещение по столбцам кратно 2·drop, по рядам любое', () {
      final ImageToGridSettings s = const ImageToGridSettings(
        technique: Technique.peyote,
        columns: 51,
      ).copyWith(rows: 10, fit: FrameFit.margins);
      final FramePlan plan = FramePlanner.plan(
        sourceWidth: 100,
        sourceHeight: 300,
        crop: CropRect.full,
        settings: s,
      );
      expect(plan.offsetColumn.isEven, isTrue);
      expect(plan.offsetColumn + plan.innerColumns, lessThanOrEqualTo(51));
      expect(plan.innerColumns, lessThan(51));
    });

    test('brick: смещение по рядам чётное', () {
      final ImageToGridSettings s = const ImageToGridSettings(
        technique: Technique.brick,
        columns: 10,
      ).copyWith(rows: 51, fit: FrameFit.margins);
      final FramePlan plan = FramePlanner.plan(
        sourceWidth: 1000,
        sourceHeight: 100,
        crop: CropRect.full,
        settings: s,
      );
      expect(plan.offsetRow.isEven, isTrue);
      expect(plan.offsetRow + plan.innerRows, lessThanOrEqualTo(51));
      expect(plan.innerRows, lessThan(51));
    });
  });

  group('PatternFrame.pad', () {
    test('сдвигает сетку, lines, partials и клетки блендов; палитра не меняется', () {
      final GeneratedPattern inner = GeneratedPattern(
        grid: Grid.fromCells(width: 3, height: 2, cells: <int>[1, 2, 0, 2, 1, 1]),
        palette: <PaletteEntry>[
          const PaletteEntry(rgb: Rgb(1, 2, 3)),
          const PaletteEntry(rgb: Rgb(4, 5, 6)),
        ],
        blendSuggestions: <BlendSuggestion>[
          BlendSuggestion(first: 0, second: 1, rgb: const Rgb(2, 3, 4), cells: const <int>[1, 3], meanGain: 3),
        ],
        lines: <LineStitch>[
          LineStitch(
            a: const LatticeNode.corner(0, 0),
            b: const LatticeNode.corner(1, 0),
            kind: LineKind.backstitch,
            color: 2,
          ),
        ],
        partials: <PartialStitch>[
          PartialStitch(
            column: 2,
            row: 1,
            kind: PartialKind.half,
            orientation: StitchOrientation.slash,
            color: 1,
          ),
        ],
      );
      const FramePlan plan = FramePlan(
        effectiveCrop: CropRect.full,
        innerColumns: 3,
        innerRows: 2,
        offsetColumn: 2,
        offsetRow: 1,
        columns: 8,
        rows: 5,
      );

      final GeneratedPattern out = PatternFrame.pad(inner, plan, 8, 5);

      expect((out.grid.width, out.grid.height), (8, 5));
      expect(out.grid.at(2, 1), 1);
      expect(out.grid.at(3, 1), 2);
      expect(out.grid.at(4, 1), 0);
      expect(out.grid.at(2, 2), 2);
      expect(out.grid.at(4, 2), 1);
      expect(out.grid.cells.where((v) => v != 0).length, 5);
      expect(out.palette, inner.palette);
      expect(out.lines.single.from, const LatticeNode.corner(2, 1));
      expect(out.lines.single.to, const LatticeNode.corner(3, 1));
      expect(out.partials.single.column, 4);
      expect(out.partials.single.row, 2);
      // клетки 1 (колонка 1, ряд 0) и 3 (колонка 0, ряд 1) во внутренней сетке 3 × 2
      expect(out.blendSuggestions.single.cells, <int>[1 * 8 + 3, 2 * 8 + 2]);
    });

    test('без полей возвращает схему как есть, слишком малая полная сетка — ошибка', () {
      final GeneratedPattern inner = GeneratedPattern(
        grid: Grid.empty(width: 3, height: 2),
        palette: const <PaletteEntry>[],
      );
      const FramePlan same = FramePlan(
        effectiveCrop: CropRect.full,
        innerColumns: 3,
        innerRows: 2,
        offsetColumn: 0,
        offsetRow: 0,
        columns: 3,
        rows: 2,
      );
      expect(identical(PatternFrame.pad(inner, same, 3, 2), inner), isTrue);
      expect(() => PatternFrame.pad(inner, same, 2, 2), throwsArgumentError);
    });
  });

  group('конвейер с рамкой', () {
    test('без frame результат прежний, с margins поля пустые', () {
      final image = blockImage(<List<int>>[
        <int>[0xFF0000, 0x00FF00],
        <int>[0x0000FF, 0xFFFF00],
      ], block: 4);
      const ImageToGridPipeline pipeline = ImageToGridPipeline();
      const ImageToGridSettings s = ImageToGridSettings(columns: 8);
      final GeneratedPattern plain = pipeline.run(s.toRequest(image: image));
      expect(plain.grid.width, 8);

      final ImageToGridSettings fixed = s.copyWith(rows: 20, fit: FrameFit.margins);
      final request = fixed.toRequest(image: image);
      expect(request.frame, isNotNull);
      final GeneratedPattern padded = pipeline.run(request);
      expect((padded.grid.width, padded.grid.height), (8, 20));
      final FramePlan plan = request.frame!;
      expect(padded.stats, isNotNull);
      for (int r = 0; r < 20; r++) {
        for (int c = 0; c < 8; c++) {
          final bool insideInner =
              c >= plan.offsetColumn &&
              c < plan.offsetColumn + plan.innerColumns &&
              r >= plan.offsetRow &&
              r < plan.offsetRow + plan.innerRows;
          if (!insideInner) expect(padded.grid.at(c, r), 0, reason: 'поле $c,$r');
        }
      }
    });
  });
}
