import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../grid/fake_cell_metrics.dart';
import 'image_fixtures.dart';

ImageToGridRequest request(
  SourceImage image, {
  required int columns,
  required int rows,
  int maxColors = 8,
  PaletteConstraint constraint = const PaletteConstraint.free(),
  bool dither = false,
  int seed = 0,
  Float32List? importance,
  List<PatternStep> steps = const <PatternStep>[],
  GridGeometry geometry = const GridGeometry.rectangular(),
  ImagePrefilter? prefilter,
}) => ImageToGridRequest(
  image: image,
  geometry: geometry,
  metrics: const FakeCellMetrics(1, 1),
  columns: columns,
  rows: rows,
  maxColors: maxColors,
  constraint: constraint,
  dither: dither,
  seed: seed,
  importance: importance,
  steps: steps,
  prefilter: prefilter,
);

class _CaptureImportance implements PatternStep {
  _CaptureImportance(this.onImportance);

  final void Function(Float32List weights) onImportance;

  @override
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context) {
    onImportance(context.cellImportance);
    return pattern;
  }
}

class _ReplaceWithOnes implements PatternStep {
  _ReplaceWithOnes(this.log);

  final List<String> log;

  @override
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context) {
    log.add('ones');
    return GeneratedPattern(
      grid: Grid.fromCells(
        width: pattern.grid.width,
        height: pattern.grid.height,
        cells: List<int>.filled(pattern.grid.width * pattern.grid.height, 1),
      ),
      palette: pattern.palette.take(1).toList(),
    );
  }
}

class _Recorder implements PatternStep {
  _Recorder(this.log, this.seen);

  final List<String> log;
  final List<PatternStepContext> seen;

  @override
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context) {
    log.add('recorder:${pattern.palette.length}');
    seen.add(context);
    return pattern;
  }
}

void main() {
  const ImageToGridPipeline pipeline = ImageToGridPipeline();

  group('ImageToGridPipeline', () {
    test('однотонная картинка — один цвет', () {
      final GeneratedPattern result = pipeline.run(
        request(SourceImage.solid(width: 40, height: 40, r: 12, g: 200, b: 99), columns: 8, rows: 8),
      );

      expect(result.palette, <PaletteEntry>[const PaletteEntry(rgb: Rgb(12, 200, 99))]);
      expect(result.grid.cells, everyElement(1));
    });

    test('шахматка из двух цветов даёт точную схему', () {
      const int a = 0x102030;
      const int b = 0xE0D0C0;
      final SourceImage image = blockImage(<List<int>>[
        <int>[a, b, a, b],
        <int>[b, a, b, a],
        <int>[a, b, a, b],
      ], block: 7);

      final GeneratedPattern result = pipeline.run(request(image, columns: 4, rows: 3, maxColors: 2));

      expect(result.palette.map((e) => e.rgb.hex).toSet(), <String>{'#102030', '#E0D0C0'});
      expect(result.palette, hasLength(2));
      final int first = result.grid.at(0, 0);
      final int second = result.grid.at(1, 0);
      expect(first, isNot(second));
      for (int row = 0; row < 3; row++) {
        for (int column = 0; column < 4; column++) {
          expect(result.grid.at(column, row), (row + column).isEven ? first : second, reason: '($column, $row)');
        }
      }
    });

    test('число цветов не больше заданного', () {
      final SourceImage image = grayRamp(width: 120, height: 20);

      for (final int maxColors in <int>[1, 2, 5, 9]) {
        final GeneratedPattern result = pipeline.run(request(image, columns: 60, rows: 10, maxColors: maxColors));

        expect(result.palette.length, lessThanOrEqualTo(maxColors));
        expect(result.palette, isNotEmpty);
        expect(result.grid.cells.every((v) => v >= 1 && v <= result.palette.length), isTrue);
      }
    });

    test('палитра упорядочена по частоте, лишних цветов нет', () {
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xFF0000, 0x00FF00, 0x00FF00, 0x00FF00],
      ], block: 3);

      final GeneratedPattern result = pipeline.run(request(image, columns: 4, rows: 1, maxColors: 5));

      expect(result.palette.map((e) => e.rgb), <Rgb>[const Rgb(0, 255, 0), const Rgb(255, 0, 0)]);
      expect(result.grid.cells, <int>[2, 1, 1, 1]);
    });

    test('прозрачный участок остаётся пустым', () {
      final Uint8List bytes = blockImage(<List<int>>[
        <int>[0xFF0000, 0x00FF00],
      ], block: 4).rgba;
      for (int y = 0; y < 4; y++) {
        for (int x = 4; x < 8; x++) {
          bytes[(y * 8 + x) * 4 + 3] = 0;
        }
      }

      final GeneratedPattern result = pipeline.run(
        request(SourceImage(width: 8, height: 4, rgba: bytes), columns: 2, rows: 1),
      );

      expect(result.grid.cells, <int>[1, 0]);
      expect(result.palette, hasLength(1));
    });

    test('полностью прозрачная картинка даёт пустую схему без палитры', () {
      final GeneratedPattern result = pipeline.run(
        request(
          blockImage(<List<int>>[
            <int>[0xFF0000],
          ], alpha: 0),
          columns: 2,
          rows: 2,
        ),
      );

      expect(result.palette, isEmpty);
      expect(result.grid.cells, everyElement(0));
    });

    test('один вход и одно зерно дают одну схему', () {
      final SourceImage image = grayRamp(width: 90, height: 30);

      final GeneratedPattern a = pipeline.run(
        request(image, columns: 30, rows: 10, maxColors: 4, dither: true, seed: 3),
      );
      final GeneratedPattern b = pipeline.run(
        request(image, columns: 30, rows: 10, maxColors: 4, dither: true, seed: 3),
      );

      expect(a.grid, b.grid);
      expect(a.palette, b.palette);
    });

    test('дизеринг добавляет промежуточные тона на градиенте с двумя цветами', () {
      final SourceImage image = grayRamp(width: 100, height: 100);
      final PaletteConstraint blackWhite = PaletteConstraint.list(const <PaletteEntry>[
        PaletteEntry(rgb: Rgb(0, 0, 0)),
        PaletteEntry(rgb: Rgb(255, 255, 255)),
      ]);

      final GeneratedPattern plain = pipeline.run(
        request(image, columns: 20, rows: 20, constraint: blackWhite, maxColors: 2),
      );
      final GeneratedPattern dithered = pipeline.run(
        request(image, columns: 20, rows: 20, constraint: blackWhite, maxColors: 2, dither: true),
      );

      // Без дизеринга в каждом ряду одна граница; с дизерингом на середине ряда цвета чередуются.
      int switches(GeneratedPattern p) {
        int count = 0;
        for (int column = 1; column < 20; column++) {
          if (p.grid.at(column, 10) != p.grid.at(column - 1, 10)) count++;
        }
        return count;
      }

      expect(switches(plain), 1);
      expect(switches(dithered), greaterThan(3));
    });

    group('ограничение палитры', () {
      final List<CatalogColor> catalog = <CatalogColor>[
        catalogColor('DB0001', 'Black', '#000000'),
        catalogColor('DB0002', 'White', '#FFFFFF'),
        catalogColor('DB0003', 'Red', '#FF0000'),
        catalogColor('DB0004', 'Blue', '#0000FF'),
        catalogColor('310', 'Floss black', '#010101', brand: 'DMC', material: CatalogMaterial.floss),
      ];
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xF03030, 0x3030F0],
        <int>[0x101010, 0xF0F0F0],
      ], block: 5);

      test('только каталог: цвета схемы — позиции каталога выбранного материала', () {
        final GeneratedPattern result = pipeline.run(
          request(
            image,
            columns: 2,
            rows: 2,
            maxColors: 4,
            constraint: PaletteConstraint.catalog(catalog, material: CatalogMaterial.bead),
          ),
        );

        expect(result.palette.map((e) => e.catalog!.code).toSet(), <String>{
          'DB0003',
          'DB0004',
          'DB0001',
          'DB0002',
        });
        expect(result.palette.every((e) => e.catalog!.material == CatalogMaterial.bead), isTrue);
      });

      test('каталог больше лимита цветов: выбираются ближайшие к картинке, не больше лимита', () {
        final GeneratedPattern result = pipeline.run(
          request(
            image,
            columns: 2,
            rows: 2,
            maxColors: 2,
            constraint: PaletteConstraint.catalog(catalog, material: CatalogMaterial.bead),
          ),
        );

        expect(result.palette.length, lessThanOrEqualTo(2));
        expect(result.palette.every((e) => e.catalog != null), isTrue);
      });

      test('заданный список: только его цвета, лишние в палитру не попадают', () {
        final PaletteConstraint stock = PaletteConstraint.list(<PaletteEntry>[
          PaletteEntry.fromCatalog(catalog[0]),
          PaletteEntry.fromCatalog(catalog[1]),
          PaletteEntry.fromCatalog(catalog[2]),
        ]);

        final GeneratedPattern result = pipeline.run(
          request(image, columns: 2, rows: 2, maxColors: 3, constraint: stock),
        );

        // Синего в запасах нет: ячейка берёт ближайший из имеющихся.
        expect(
          result.palette.map((e) => e.catalog!.code).toSet().difference(<String>{
            'DB0001',
            'DB0002',
            'DB0003',
          }),
          isEmpty,
        );
        expect(result.grid.cells, everyElement(greaterThan(0)));
      });

      test('пустой список отклоняется', () {
        expect(
          () => request(image, columns: 2, rows: 2, constraint: PaletteConstraint.list(const <PaletteEntry>[])),
          throwsArgumentError,
        );
      });
    });

    test('маска важности: важное получает свой цвет, фон — нет', () {
      // Широкий «фон» из оттенков синего и маленькое пятно цвета кожи.
      final List<List<int>> blocks = <List<int>>[
        for (int y = 0; y < 8; y++)
          <int>[for (int x = 0; x < 8; x++) (x == 3 && y == 3) ? 0xE8B090 : 0x2040A0 + (x + y)],
      ];
      final SourceImage image = blockImage(blocks, block: 4);
      final Float32List mask = Float32List(image.width * image.height)..fillRange(0, image.width * image.height, 1);
      for (int y = 12; y < 16; y++) {
        for (int x = 12; x < 16; x++) {
          mask[y * image.width + x] = 50;
        }
      }

      final GeneratedPattern result = pipeline.run(request(image, columns: 8, rows: 8, maxColors: 2, importance: mask));

      expect(result.palette, hasLength(2));
      expect(result.grid.at(3, 3), isNot(result.grid.at(0, 0)));
    });

    test('шаги после привязки вызываются по порядку и видят контекст', () {
      final List<String> log = <String>[];
      final List<PatternStepContext> seen = <PatternStepContext>[];
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xFF0000, 0x00FF00],
      ], block: 4);

      final GeneratedPattern result = pipeline.run(
        request(
          image,
          columns: 2,
          rows: 1,
          steps: <PatternStep>[_Recorder(log, seen), _ReplaceWithOnes(log), _Recorder(log, seen)],
          geometry: const GridGeometry.brick(),
        ),
      );

      expect(log, <String>['recorder:2', 'ones', 'recorder:1']);
      expect(result.grid.cells, <int>[1, 1]);
      expect(seen.first.geometry, const GridGeometry.brick());
      expect(seen.first.cellImportance, <double>[1, 1]);
    });

    test('конвейер совместим с геометрией пейота', () {
      final SourceImage image = SourceImage.solid(width: 30, height: 30, r: 5, g: 5, b: 5);

      final GeneratedPattern result = pipeline.run(
        request(image, columns: 6, rows: 5, geometry: const GridGeometry.peyote()),
      );

      expect(result.grid.cells, everyElement(1));
    });

    test('производительность: 1000×1000 → 60×200, 12 цветов быстрее 2 секунд', () {
      final Uint8List bytes = Uint8List(1000 * 1000 * 4);
      for (int y = 0; y < 1000; y++) {
        for (int x = 0; x < 1000; x++) {
          final int o = (y * 1000 + x) * 4;
          bytes[o] = x * 255 ~/ 999;
          bytes[o + 1] = y * 255 ~/ 999;
          bytes[o + 2] = (x + y) * 255 ~/ 1998;
          bytes[o + 3] = 255;
        }
      }
      final SourceImage image = SourceImage(width: 1000, height: 1000, rgba: bytes);

      final Stopwatch watch = Stopwatch()..start();
      final GeneratedPattern result = pipeline.run(request(image, columns: 60, rows: 200, maxColors: 12, dither: true));
      watch.stop();

      expect(result.palette.length, lessThanOrEqualTo(12));
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });
  });

  group('подготовка фото в конвейере', () {
    // Белый фон с чёрным квадратом, поверх — шум ±12 по каждому пикселю.
    SourceImage noisySquare() {
      final math.Random random = math.Random(3);
      final Uint8List bytes = Uint8List(40 * 40 * 4);
      for (int y = 0; y < 40; y++) {
        for (int x = 0; x < 40; x++) {
          final int base = (x >= 10 && x < 30 && y >= 10 && y < 30) ? 20 : 235;
          final int v = base + random.nextInt(25) - 12;
          final int o = (y * 40 + x) * 4;
          bytes[o] = v;
          bytes[o + 1] = v;
          bytes[o + 2] = v;
          bytes[o + 3] = 255;
        }
      }
      return SourceImage(width: 40, height: 40, rgba: bytes);
    }

    test('без префильтра результат тот же, что у конвейера до T52', () {
      final SourceImage image = noisySquare();
      final GeneratedPattern plain = const ImageToGridPipeline().run(request(image, columns: 20, rows: 20));
      final GeneratedPattern again = const ImageToGridPipeline().run(request(image, columns: 20, rows: 20));
      expect(plain.grid.cells, again.grid.cells);
    });

    test('с префильтром цвета ячеек чище, схема той же формы и детерминирована', () {
      final SourceImage image = noisySquare();
      final GeneratedPattern a = const ImageToGridPipeline().run(
        request(image, columns: 20, rows: 20, maxColors: 2, prefilter: const EdgePreservingPrefilter()),
      );
      final GeneratedPattern b = const ImageToGridPipeline().run(
        request(image, columns: 20, rows: 20, maxColors: 2, prefilter: const EdgePreservingPrefilter()),
      );
      expect(a.grid.cells, b.grid.cells);
      expect(a.grid.width, 20);
      expect(a.grid.height, 20);
      expect(a.palette, hasLength(2));
      // Центр квадрата и фон — разные цвета, края квадрата на месте.
      expect(a.grid.at(10, 10), isNot(a.grid.at(1, 1)));
    });

    test('маска важности доходит до шагов в рабочем разрешении', () {
      final SourceImage image = noisySquare();
      final Float32List mask = Float32List(40 * 40)..fillRange(0, 40 * 40, 2);
      Float32List? seen;
      const ImageToGridPipeline().run(
        request(
          image,
          columns: 4,
          rows: 4,
          importance: mask,
          prefilter: const EdgePreservingPrefilter(),
          steps: <PatternStep>[_CaptureImportance((w) => seen = w)],
        ),
      );
      expect(seen, isNotNull);
      expect(seen!.every((w) => (w - 2).abs() < 1e-4), isTrue);
    });

    test('12 Мпикс: рабочая картинка для 150×200 строится быстрее секунды', () {
      final SourceImage big = SourceImage.solid(width: 3000, height: 4000, r: 120, g: 90, b: 60);
      final Stopwatch watch = Stopwatch()..start();
      final WorkImage work = WorkImage.fromSource(
        image: big,
        geometry: const GridGeometry.rectangular(),
        metrics: const FakeCellMetrics(1, 1),
        columns: 150,
        rows: 200,
      );
      watch.stop();
      expect(work.width, 600);
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('ImageToGridRequest', () {
    final SourceImage image = SourceImage.solid(width: 2, height: 2, r: 0, g: 0, b: 0);

    test('неверные размеры и число цветов отклоняются', () {
      expect(() => request(image, columns: 0, rows: 1), throwsArgumentError);
      expect(() => request(image, columns: 1, rows: Grid.maxSide + 1), throwsArgumentError);
      expect(() => request(image, columns: 1, rows: 1, maxColors: 0), throwsArgumentError);
    });

    test('маска неверной длины или с плохими весами отклоняется', () {
      expect(() => request(image, columns: 1, rows: 1, importance: Float32List(3)), throwsArgumentError);
      expect(
        () => request(image, columns: 1, rows: 1, importance: Float32List.fromList(<double>[1, 1, -1, 1])),
        throwsArgumentError,
      );
      expect(
        () => request(image, columns: 1, rows: 1, importance: Float32List.fromList(<double>[1, 1, double.nan, 1])),
        throwsArgumentError,
      );
    });
  });

  group('SourceImage', () {
    test('неверный размер или длина буфера отклоняются', () {
      expect(() => SourceImage(width: 0, height: 1, rgba: Uint8List(0)), throwsArgumentError);
      expect(() => SourceImage(width: 1, height: 0, rgba: Uint8List(0)), throwsArgumentError);
      expect(() => SourceImage(width: 2, height: 2, rgba: Uint8List(15)), throwsArgumentError);
    });
  });

  group('stats', () {
    test('считает одиночные клетки, цвета и среднюю ΔE; время стадий записано', () {
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xFF0000, 0xFF0000, 0xFF0000],
        <int>[0xFF0000, 0x0000FF, 0xFF0000],
        <int>[0xFF0000, 0xFF0000, 0xFF0000],
      ]);
      final GeneratedPattern pattern = const ImageToGridPipeline().run(
        request(image, columns: 3, rows: 3, maxColors: 2),
      );
      final stats = pattern.stats!;
      expect(stats.singleCells, 1);
      expect(stats.colorCount, 2);
      expect(stats.meanDeltaE, lessThan(0.5));
      expect(stats.stageTimes.keys, <String>['sample', 'palette', 'assign', 'steps']);
      expect(stats.totalTime, greaterThanOrEqualTo(Duration.zero));
    });

    test('у пустой картинки метрики нулевые', () {
      final SourceImage image = blockImage(<List<int>>[
        <int>[0xFF0000],
      ], alpha: 0);
      final GeneratedPattern pattern = const ImageToGridPipeline().run(request(image, columns: 1, rows: 1));
      expect(pattern.stats!.meanDeltaE, 0);
      expect(pattern.stats!.colorCount, 0);
    });
  });

  group('бленды (T57)', () {
    // Слева красный, справа жёлтый, посередине оранжевый: оранжевый ближе к бленду двух ниток, чем к любому из двух.
    final SourceImage photo = blockImage(<List<int>>[
      <int>[for (int i = 0; i < 12; i++) i < 4 ? 0xC82828 : (i < 8 ? 0xE48C30 : 0xE6C832)],
    ], block: 3);

    ImageToGridRequest build({required bool blends, bool draft = false}) => ImageToGridRequest(
      image: photo,
      geometry: const GridGeometry.rectangular(),
      metrics: const FakeCellMetrics(1, 1),
      columns: 12,
      rows: 1,
      maxColors: 2,
      suggestBlends: blends,
      draft: draft,
    );

    test('без запроса предложений нет и время стадии не пишется', () {
      final GeneratedPattern result = pipeline.run(build(blends: false));
      expect(result.blendSuggestions, isEmpty);
      expect(result.stats!.stageTimes.containsKey('blends'), isFalse);
    });

    test('с запросом результат содержит поле, стадия учтена; черновик бленды не ищет', () {
      final GeneratedPattern result = pipeline.run(build(blends: true));
      expect(result.stats!.stageTimes.containsKey('blends'), isTrue);
      expect(pipeline.run(build(blends: true, draft: true)).stats!.stageTimes.containsKey('blends'), isFalse);
    });
  });
}
