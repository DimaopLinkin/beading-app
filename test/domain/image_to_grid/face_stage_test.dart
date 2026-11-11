import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_costs.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/face_guide.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/image_to_grid/face_size_advisor.dart';
import 'package:beading/domain/image_to_grid/face_step.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

const int _side = 120;

/// Портрет из кубиков: серый фон, овал кожи с мягким переходом оттенков и шумом, два глаза с тёмным зрачком,
/// линия красных губ. Всё детерминировано.
SourceImage _face() {
  final Uint8List rgba = Uint8List(_side * _side * 4);
  final math.Random noise = math.Random(7);
  for (int y = 0; y < _side; y++) {
    for (int x = 0; x < _side; x++) {
      final double nx = x / _side;
      final double ny = y / _side;
      int r = 200;
      int g = 200;
      int b = 212;
      final double dx = (nx - 0.5) / 0.25;
      final double dy = (ny - 0.5) / 0.3;
      if (dx * dx + dy * dy <= 1) {
        final double shade = 1 - 0.12 * (nx - 0.5).abs() * 4 - 0.08 * (ny - 0.2);
        final int n = noise.nextInt(11) - 5;
        r = (232 * shade + n).round();
        g = (184 * shade + n).round();
        b = (156 * shade + n).round();
      }
      void paint(double cx, double cy, double rx, double ry, List<int> c) {
        final double ex = (nx - cx) / rx;
        final double ey = (ny - cy) / ry;
        if (ex * ex + ey * ey <= 1) {
          r = c[0];
          g = c[1];
          b = c[2];
        }
      }

      paint(0.4, 0.42, 0.05, 0.035, <int>[250, 250, 250]); // белок
      paint(0.6, 0.42, 0.05, 0.035, <int>[250, 250, 250]);
      paint(0.4, 0.42, 0.025, 0.03, <int>[40, 30, 28]); // зрачок
      paint(0.6, 0.42, 0.025, 0.03, <int>[40, 30, 28]);
      paint(0.5, 0.66, 0.08, 0.012, <int>[190, 60, 72]); // губы
      final int i = (y * _side + x) * 4;
      rgba[i] = r.clamp(0, 255);
      rgba[i + 1] = g.clamp(0, 255);
      rgba[i + 2] = b.clamp(0, 255);
      rgba[i + 3] = 255;
    }
  }
  return SourceImage(width: _side, height: _side, rgba: rgba);
}

List<NormalizedPoint> _ring(double cx, double cy, double rx, double ry) => <NormalizedPoint>[
  NormalizedPoint(cx - rx, cy),
  NormalizedPoint(cx, cy - ry),
  NormalizedPoint(cx + rx, cy),
  NormalizedPoint(cx, cy + ry),
];

ImageMaskSet _masks({bool withFace = true}) => ImageMaskSet(
  width: _side,
  height: _side,
  faces: withFace
      ? <DetectedFace>[
          DetectedFace(
            bounds: const NormalizedRect(left: 0.25, top: 0.2, right: 0.75, bottom: 0.8),
            landmarks: FaceLandmarks(
              leftEye: _ring(0.4, 0.42, 0.04, 0.02),
              rightEye: _ring(0.6, 0.42, 0.04, 0.02),
              leftPupil: const <NormalizedPoint>[NormalizedPoint(0.4, 0.42)],
              rightPupil: const <NormalizedPoint>[NormalizedPoint(0.6, 0.42)],
              innerLips: const <NormalizedPoint>[NormalizedPoint(0.42, 0.66), NormalizedPoint(0.58, 0.66)],
              outerLips: _ring(0.5, 0.66, 0.08, 0.02),
            ),
          ),
        ]
      : const <DetectedFace>[],
);

ImageToGridSettings get _settings => const ImageToGridSettings(maxColors: 10, paletteSource: PaletteSource.free);

GeneratedPattern _run(ImageMaskSet? masks) {
  final SourceImage image = _face();
  final ImageToGridRequest request = _settings.toRequest(image: image, masks: masks);
  return const ImageToGridPipeline().run(request);
}

/// Лица в клетках для схемы [pattern], собранной из [_face] с теми же настройками.
FaceCells _cellsOf(GeneratedPattern pattern) {
  final ImageToGridRequest request = _settings.toRequest(image: _face(), masks: _masks());
  final WorkImage work = WorkImage.fromSource(
    image: request.image,
    geometry: request.geometry,
    metrics: request.metrics,
    columns: request.columns,
    rows: request.rows,
  );
  final CellRegions regions = CellRegions.forGrid(
    geometry: request.geometry,
    metrics: request.metrics,
    columns: request.columns,
    rows: request.rows,
    imageWidth: work.width,
    imageHeight: work.height,
  );
  return FaceGuide(_masks()).cells(regions, workWidth: work.width, workHeight: work.height);
}

double _lightness(GeneratedPattern p, int cell) {
  final int v = p.grid.at(cell % p.grid.width, cell ~/ p.grid.width);
  return Lab.fromRgb(p.palette[v - 1].rgb).l;
}

int _singlesIn(GeneratedPattern pattern, Uint8List mask) {
  final Grid g = pattern.grid;
  int count = 0;
  for (int i = 0; i < mask.length; i++) {
    if (mask[i] == 0) continue;
    final int x = i % g.width;
    final int y = i ~/ g.width;
    final int v = g.at(x, y);
    bool same = false;
    for (final (int, int) d in const <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final int nx = x + d.$1;
      final int ny = y + d.$2;
      if (nx >= 0 && ny >= 0 && nx < g.width && ny < g.height && g.at(nx, ny) == v) same = true;
    }
    if (!same) count++;
  }
  return count;
}

void main() {
  group('FaceSizeAdvisor', () {
    const FaceSizeAdvisor advisor = FaceSizeAdvisor();
    ImageMaskSet withWidth(double w) => ImageMaskSet(
      width: 10,
      height: 10,
      faces: <DetectedFace>[
        DetectedFace(
          bounds: NormalizedRect(left: 0.3, top: 0.2, right: 0.3 + w, bottom: 0.2 + w),
        ),
      ],
    );

    test('лицо в 20 клеток и больше: предупреждения нет', () {
      expect(advisor.advise(withWidth(0.5), columns: 40), isNull);
      expect(advisor.advise(withWidth(0.5), columns: 40), isNull);
    });

    test('без лиц предупреждения нет', () {
      expect(advisor.advise(ImageMaskSet.empty(width: 10, height: 10), columns: 40), isNull);
    });

    test('мелкое лицо: сколько клеток нужно и в какую область обрезать', () {
      final FaceSizeAdvice advice = advisor.advise(withWidth(0.2), columns: 40)!;
      expect(advice.faceCells, closeTo(8, 1e-9));
      expect(advice.neededColumns, 100);
      final NormalizedRect crop = advice.cropRect!;
      expect(crop.width, closeTo(crop.height, 1e-9)); // те же пропорции, что у фото
      expect(0.2 / crop.width * 40, greaterThanOrEqualTo(20)); // после обрезки лицо не меньше порога
      expect(crop.left, lessThanOrEqualTo(0.3));
      expect(crop.right, greaterThanOrEqualTo(0.5));
      expect(crop.left, greaterThanOrEqualTo(0));
      expect(crop.right, lessThanOrEqualTo(1));
    });

    test('совсем мелкое лицо: ни ширина, ни обрезка не помогают', () {
      final FaceSizeAdvice advice = advisor.advise(withWidth(0.02), columns: 20)!;
      expect(advice.neededColumns, isNull);
      expect(advice.cropRect, isNull);
    });

    test('советует по самому крупному лицу', () {
      final ImageMaskSet masks = ImageMaskSet(
        width: 10,
        height: 10,
        faces: const <DetectedFace>[
          DetectedFace(bounds: NormalizedRect(left: 0.05, top: 0.1, right: 0.1, bottom: 0.15)),
          DetectedFace(bounds: NormalizedRect(left: 0.3, top: 0.1, right: 0.85, bottom: 0.65)),
        ],
      );
      expect(advisor.advise(masks, columns: 40), isNull);
    });
  });

  group('лица в схеме', () {
    test('без лиц результат не меняется', () {
      final Grid plain = _run(null).grid;
      expect(_run(_masks(withFace: false)).grid, plain);
    });

    test('кожа лица — не больше четырёх цветов и без одиночных клеток', () {
      final GeneratedPattern pattern = _run(_masks());
      final FaceCells cells = _cellsOf(pattern);
      final Set<int> colors = <int>{};
      int skinCells = 0;
      for (int i = 0; i < cells.skin.length; i++) {
        if (!cells.isSkin(i)) continue;
        skinCells++;
        colors.add(pattern.grid.at(i % pattern.grid.width, i ~/ pattern.grid.width));
      }
      expect(skinCells, greaterThan(100));
      expect(colors.length, lessThanOrEqualTo(4));
      expect(colors.contains(0), isFalse);
      expect(_singlesIn(pattern, cells.skin), 0);
    });

    test('зрачок каждого глаза — тёмная клетка', () {
      final GeneratedPattern pattern = _run(_masks());
      final FaceCells cells = _cellsOf(pattern);
      expect(cells.pupils.length, greaterThanOrEqualTo(2));
      for (final int cell in cells.pupils) {
        expect(_lightness(pattern, cell), lessThan(40), reason: 'клетка $cell');
      }
    });

    test('линия губ берёт насыщенный цвет, а не цвет кожи', () {
      final GeneratedPattern pattern = _run(_masks());
      final FaceCells cells = _cellsOf(pattern);
      expect(cells.lips, isNotEmpty);
      double chroma(int cell) {
        final int v = pattern.grid.at(cell % pattern.grid.width, cell ~/ pattern.grid.width);
        final Lab lab = Lab.fromRgb(pattern.palette[v - 1].rgb);
        return math.sqrt(lab.a * lab.a + lab.b * lab.b);
      }

      final double lips = cells.lips.map(chroma).reduce(math.max);
      final List<int> skin = <int>[
        for (int i = 0; i < cells.skin.length; i++)
          if (cells.isSkin(i)) i,
      ];
      final double skinMax = skin.map(chroma).reduce(math.max);
      expect(lips, greaterThanOrEqualTo(skinMax));
    });

    test('шаг: зрачок берёт тёмный цвет только из лучших для клетки', () {
      // Цвета: 1 — кожа, 2 — розовый, 3 — тёмный, 4 — очень тёмный (но по цене далеко).
      final GeneratedPattern pattern = GeneratedPattern(
        grid: Grid.fromCells(width: 2, height: 1, cells: <int>[1, 1]),
        palette: const <PaletteEntry>[
          PaletteEntry(rgb: Rgb(230, 180, 150)),
          PaletteEntry(rgb: Rgb(200, 120, 120)),
          PaletteEntry(rgb: Rgb(70, 50, 45)),
          PaletteEntry(rgb: Rgb(5, 5, 5)),
        ],
      );
      final CellCosts costs = CellCosts(
        columns: 2,
        rows: 1,
        colorCount: 4,
        values: Float32List.fromList(<double>[
          5, 9, 8, 40, // клетка 0: тёмный №3 — третий по цене, №4 — последний
          5, 9, 30, 20, // клетка 1: тёмный №3 четвёртый (не среди лучших трёх)
        ]),
      );
      final PatternStepContext context = PatternStepContext(
        geometry: const GridGeometry.rectangular(),
        cellImportance: Float32List.fromList(<double>[1, 1]),
        costs: costs,
        faces: FaceCells(
          columns: 2,
          rows: 1,
          skin: Uint8List(2),
          feature: Uint8List.fromList(<int>[1, 1]),
          pupils: const <int>[0, 1],
          lips: const <int>[],
        ),
      );
      final GeneratedPattern out = const FaceFeatureStep().apply(pattern, context);
      expect(out.grid.at(0, 0), 3); // тёмный из трёх лучших
      expect(out.grid.at(1, 0), 4); // №3 не среди трёх лучших (цены 5, 9, 20): самый тёмный из лучших
    });

    test('шаг без лиц или без цен ничего не меняет', () {
      final GeneratedPattern pattern = _run(null);
      final PatternStepContext context = PatternStepContext(
        geometry: const GridGeometry.rectangular(),
        cellImportance: Float32List(pattern.grid.width * pattern.grid.height),
      );
      expect(const FaceFeatureStep().apply(pattern, context), same(pattern));
    });

    test('peyote и «детально»: кожа — не больше 4 цветов, цветов не больше заданного', () {
      for (final GenerationPreset preset in GenerationPreset.values) {
        final ImageToGridSettings settings = _settings.copyWith(technique: Technique.peyote, preset: preset);
        final GeneratedPattern pattern = const ImageToGridPipeline().run(
          settings.toRequest(image: _face(), masks: _masks()),
        );
        final ImageToGridRequest request = settings.toRequest(image: _face(), masks: _masks());
        final WorkImage work = WorkImage.fromSource(
          image: request.image,
          geometry: request.geometry,
          metrics: request.metrics,
          columns: request.columns,
          rows: request.rows,
        );
        final FaceCells cells = FaceGuide(_masks()).cells(
          CellRegions.forGrid(
            geometry: request.geometry,
            metrics: request.metrics,
            columns: request.columns,
            rows: request.rows,
            imageWidth: work.width,
            imageHeight: work.height,
          ),
          workWidth: work.width,
          workHeight: work.height,
        );
        final Set<int> colors = <int>{
          for (int i = 0; i < cells.skin.length; i++)
            if (cells.isSkin(i)) pattern.grid.at(i % pattern.grid.width, i ~/ pattern.grid.width),
        };
        expect(colors.length, lessThanOrEqualTo(4), reason: '$preset');
        expect(pattern.palette.length, lessThanOrEqualTo(10), reason: '$preset');
      }
    });

    test('цветов не больше заданного, результат детерминирован', () {
      final GeneratedPattern a = _run(_masks());
      expect(a.palette.length, lessThanOrEqualTo(10));
      expect(_run(_masks()).grid, a.grid);
    });

    test('пиксели кожи — внутри лица и вне черт', () {
      final Uint8List skin = FaceGuide(_masks()).skinPixels(_side, _side);
      expect(skin[(0.5 * _side).floor() * _side + (0.5 * _side).floor()], 1); // середина лица
      expect(skin[2 * _side + 2], 0); // фон
      expect(skin[(0.42 * _side).floor() * _side + (0.4 * _side).floor()], 0); // зрачок
    });
  });
}
