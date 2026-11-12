import 'package:beading/domain/catalog/bead_finish_group.dart';
import 'package:beading/domain/catalog/bead_series.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/cleanup_steps.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/technique_geometry.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';

void main() {
  final SourceImage image = SourceImage.solid(width: 100, height: 200, r: 10, g: 20, b: 30);
  final List<CatalogColor> catalog = <CatalogColor>[
    catalogColor('DB0010', 'Красный', '#C80A14', finish: 'opaque'),
    catalogColor('DB0011', 'Синий', '#0A14C8', finish: 'matte'),
    catalogColor('DB0012', 'Блестящий', '#C8C80A', finish: 'luster'),
    catalogColor('DB0013', 'Прозрачный', '#0AC8C8', finish: 'transparent'),
    catalogColor('T-1', 'Toho', '#00FF00', brand: 'Toho', series: 'Round', finish: 'opaque'),
    catalogColor('M-1', 'Нитка', '#111111', material: CatalogMaterial.floss),
  ];

  group('geometryForTechnique', () {
    test('пейот и кирпич сдвинуты, остальные ровные', () {
      expect(geometryForTechnique(Technique.peyote), isA<PeyoteGeometry>());
      expect(geometryForTechnique(Technique.brick), isA<BrickGeometry>());
      for (final Technique t in <Technique>[Technique.loom, Technique.square, Technique.offLoom]) {
        expect(geometryForTechnique(t), isA<RectangularGeometry>());
      }
    });
  });

  group('ImageToGridSettings', () {
    test('по умолчанию станок, Delica 11/0, каталог', () {
      const ImageToGridSettings s = ImageToGridSettings();
      expect(s.technique, Technique.loom);
      expect(s.beadSize, BeadSize.delica11);
      expect(s.paletteSource, PaletteSource.catalog);
    });

    test('техники мастера зависят от ремесла', () {
      expect(
        ImageToGridSettings.techniquesOf(Craft.beading),
        everyElement(predicate<Technique>((t) => t.craft == Craft.beading)),
      );
      expect(ImageToGridSettings.techniquesOf(Craft.crossStitch), <Technique>[Technique.crossStitch, Technique.tent]);
    });

    test('copyWith держит ширину и число цветов в границах', () {
      const ImageToGridSettings s = ImageToGridSettings();
      expect(s.copyWith(columns: 1).columns, ImageToGridSettings.minColumns);
      expect(s.copyWith(columns: 99999).columns, ImageToGridSettings.maxColumns);
      expect(s.copyWith(maxColors: 0).maxColors, ImageToGridSettings.minColors);
      expect(s.copyWith(maxColors: 999).maxColors, ImageToGridSettings.maxColorsLimit);
    });

    test('ряды повторяют пропорции картинки', () {
      // Картинка 1:2, ячейка Delica 11/0 чуть выше, чем шире: рядов заметно больше половины ширины в клетках...
      const ImageToGridSettings s = ImageToGridSettings();
      final int rows = s.rowsFor(image);
      expect(rows, greaterThan(40));
      expect(rows, lessThan(100));
    });

    test('каталожные цвета отбираются по бисеру, размеру, одной серии и отделкам', () {
      const ImageToGridSettings s = ImageToGridSettings();
      // По умолчанию: серия Delica (бренд не задан), матовый и блестящий.
      expect(s.catalogFor(catalog).map((c) => c.code), <String>['DB0010', 'DB0011', 'DB0012']);
      expect(s.catalogFor(catalog, brand: 'Toho').map((c) => c.code), <String>['T-1']);
      expect(s.copyWith(beadSize: BeadSize.delica15).catalogFor(catalog), isEmpty);
    });

    test('выбор серии в мастере сильнее бренда по умолчанию', () {
      const ImageToGridSettings s = ImageToGridSettings(beadSeries: BeadSeries.round);
      expect(s.catalogFor(catalog, brand: 'Miyuki').map((c) => c.code), <String>['T-1']);
      expect(
        const ImageToGridSettings(beadSeries: BeadSeries.delica).catalogFor(catalog, brand: 'Toho').map((c) => c.code),
        <String>['DB0010', 'DB0011', 'DB0012'],
      );
    });

    test('включённая группа отделок добавляет свои позиции', () {
      final ImageToGridSettings s = const ImageToGridSettings().copyWith(
        finishGroups: <BeadFinishGroup>{BeadFinishGroup.solid},
      );
      expect(s.catalogFor(catalog).map((c) => c.code), <String>['DB0010', 'DB0011']);
      expect(
        s.copyWith(finishGroups: <BeadFinishGroup>{BeadFinishGroup.transparent}).catalogFor(catalog).map((c) => c.code),
        <String>['DB0013'],
      );
    });

    test('позиции с неизвестной отделкой остаются в каталоге', () {
      final List<CatalogColor> unknown = <CatalogColor>[catalogColor('DB0099', 'Без отделки', '#101010')];
      expect(const ImageToGridSettings().catalogFor(unknown), hasLength(1));
    });

    test('все группы выключить нельзя: остаётся хотя бы одна', () {
      final ImageToGridSettings s = const ImageToGridSettings().copyWith(finishGroups: const <BeadFinishGroup>{});
      expect(s.finishGroups, ImageToGridSettings.defaultFinishGroups);
    });

    test('запрос с каталогом ограничивает палитру каталогом', () {
      final ImageToGridRequest request = const ImageToGridSettings().toRequest(
        image: image,
        catalog: catalog,
        brand: 'Miyuki',
      );
      expect(request.constraint.isFree, isFalse);
      expect(request.constraint.candidates, hasLength(3));
      expect(request.columns, 40);
      expect(request.rows, const ImageToGridSettings().rowsFor(image));
    });

    test('вес заметности (T64) подключает DetailCellLabeler и защиту диагональных линий; по умолчанию выключен', () {
      final ImageToGridRequest plain = const ImageToGridSettings(
        preset: GenerationPreset.balanced,
      ).toRequest(image: image);
      expect(plain.labeler, isA<VotingCellLabeler>());
      final ImageToGridRequest detail = const ImageToGridSettings(detailVoting: true).toRequest(image: image);
      expect(detail.labeler, isA<DetailCellLabeler>());
      expect(detail.steps.whereType<RemoveIslandsStep>().single.protectDiagonals, isTrue);
      expect(plain.steps.whereType<RemoveIslandsStep>().single.protectDiagonals, isFalse);
    });

    test('по умолчанию предустановка «детально» (выбор Дмитрия на листах T66): вес заметности входит в неё', () {
      expect(const ImageToGridSettings().preset, GenerationPreset.detailed);
      final ImageToGridRequest request = const ImageToGridSettings().toRequest(image: image);
      expect(request.labeler, isA<DetailCellLabeler>());
    });

    test('свободная палитра — без ограничений', () {
      final ImageToGridRequest request = const ImageToGridSettings(
        paletteSource: PaletteSource.free,
      ).toRequest(image: image, catalog: catalog);
      expect(request.constraint.isFree, isTrue);
    });

    test('нет цветов каталога под размер — палитра свободная, а не ошибка', () {
      final ImageToGridRequest request = const ImageToGridSettings(
        beadSize: BeadSize.delica15,
      ).toRequest(image: image, catalog: catalog);
      expect(request.constraint.isFree, isTrue);
    });
  });

  group('вышивка (T46)', () {
    final CatalogColor dmcRed = catalogColor(
      '321',
      'Красный',
      '#C80A14',
      brand: 'DMC',
      material: CatalogMaterial.floss,
    );
    final CatalogColor dmcBlue = catalogColor('797', 'Синий', '#0A14C8', brand: 'DMC', material: CatalogMaterial.floss);
    final CatalogColor otherBrand = catalogColor(
      '1',
      'Чужой',
      '#00FF00',
      brand: 'Anchor',
      material: CatalogMaterial.floss,
    );
    const ImageToGridSettings stitch = ImageToGridSettings(technique: Technique.crossStitch, columns: 140);

    test('размер ячейки — канва, а не бусина', () {
      expect(stitch.metrics, Fabric.standard);
      expect(const ImageToGridSettings().metrics, BeadSize.delica11);
    });

    test('ширина в сантиметрах считается из канвы: 140 крестиков на Аиде 14 — около 25 см', () {
      expect(stitch.widthCm, closeTo(25.4, 0.1));
      final Fabric aida18 = Fabric.create(kind: FabricKind.aida, count: 18).valueOrNull!;
      expect(stitch.copyWith(fabric: aida18).widthCm, closeTo(19.8, 0.1));
    });

    test('у вышивки ширина может быть больше, чем у бисера', () {
      expect(stitch.copyWith(columns: 99999).columns, stitch.fabric.cellsForCm(200));
      expect(const ImageToGridSettings().copyWith(columns: 99999).columns, ImageToGridSettings.maxColumns);
      // Смена техники на бисерную подрезает ширину.
      expect(stitch.copyWith(columns: 200, technique: Technique.loom).columns, ImageToGridSettings.maxColumns);
    });

    test('вышивка до 200 см шириной на любой канве, до 120 цветов', () {
      expect(ImageToGridSettings.maxColorsLimit, 120);
      for (final int count in <int>[11, 14, 20]) {
        final Fabric f = Fabric.create(kind: FabricKind.aida, count: count).valueOrNull!;
        final ImageToGridSettings s = stitch.copyWith(fabric: f, columns: 99999);
        expect(s.widthCm, closeTo(200, 0.5));
        expect(s.columns, lessThanOrEqualTo(ImageToGridSettings.maxStitchColumns));
      }
      expect(stitch.copyWith(maxColors: 999).maxColors, 120);
    });

    test('сантиметры кратны 5: 32 → 30, 47 → 45, не меньше 5 и не больше 200', () {
      expect(ImageToGridSettings.snapCm(32), 30);
      expect(ImageToGridSettings.snapCm(47), 45);
      expect(ImageToGridSettings.snapCm(0.2), 5);
      expect(ImageToGridSettings.snapCm(999), 200);
    });

    test('высота вышивки округляется до 5 см', () {
      final SourceImage image = SourceImage.solid(width: 300, height: 220, r: 0, g: 0, b: 0);
      final ImageToGridSettings s = stitch.copyWith(columns: stitch.fabric.cellsForCm(50));
      final double heightCm = s.fabric.cmForCells(s.rowsFor(image));
      expect(heightCm % 5, anyOf(closeTo(0, 0.1), closeTo(5, 0.1)));
    });

    test('огромная схема берёт меньше цветов, чтобы поместиться в память', () {
      final ImageToGridSettings s = stitch.copyWith(columns: stitch.fabric.cellsForCm(200), maxColors: 120);
      final int rows = stitch.fabric.cellsForCm(80);
      expect(s.colorsFor(rows), lessThan(120));
      expect(s.columns * rows * s.colorsFor(rows), lessThanOrEqualTo(ImageToGridSettings.costBudget));
      expect(stitch.copyWith(columns: 150, maxColors: 30).colorsFor(100), 30);
    });

    test('каталог — мулине выбранного бренда, размер бисера не важен', () {
      final List<CatalogColor> found = stitch.catalogFor(<CatalogColor>[
        ...catalog,
        dmcRed,
        dmcBlue,
        otherBrand,
      ], brand: 'DMC');
      expect(found, <CatalogColor>[dmcRed, dmcBlue]);
    });

    test('запрос: клетки по канве, контуры и бленды только у вышивки, обводка бусиной — только у бисера', () {
      final ImageToGridRequest request = stitch
          .copyWith(backstitch: true, blends: true, outline: true)
          .toRequest(image: image, catalog: <CatalogColor>[dmcRed, dmcBlue], brand: 'DMC');
      expect(request.metrics, Fabric.standard);
      expect(request.backstitch, isTrue);
      expect(request.suggestBlends, isTrue);
      expect(request.applyBlends, isTrue);
      expect(request.outline, isFalse);
      expect(request.constraint.candidates, hasLength(2));
      final ImageToGridRequest beads = const ImageToGridSettings(
        backstitch: true,
        blends: true,
        outline: true,
      ).toRequest(image: image, catalog: catalog);
      expect(beads.backstitch, isFalse);
      expect(beads.applyBlends, isFalse);
      expect(beads.outline, isTrue);
    });

    test('цвет канвы в запрос не попадает: его смена не сбрасывает кеш стадий', () {
      final ImageToGridRequest white = stitch.toRequest(image: image);
      final ImageToGridRequest black = stitch
          .copyWith(fabric: Fabric.standard.withColor(const Rgb(20, 20, 20)))
          .toRequest(image: image);
      expect(black.metrics, white.metrics);
    });

    test('контуры без предустановки (путь T24) не запрашиваются', () {
      final ImageToGridRequest request = stitch.copyWith(backstitch: true, clearPreset: true).toRequest(image: image);
      expect(request.backstitch, isFalse);
    });

    test('бленды применяются только к цветам каталога: в свободной палитре нитки взять неоткуда', () {
      final ImageToGridRequest request = stitch
          .copyWith(blends: true, paletteSource: PaletteSource.free)
          .toRequest(image: image, catalog: <CatalogColor>[dmcRed, dmcBlue], brand: 'DMC');
      expect(request.suggestBlends, isTrue);
      expect(request.applyBlends, isFalse);
    });
  });
}
