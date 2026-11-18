import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../grid/fake_cell_metrics.dart';
import 'image_fixtures.dart';

/// Серый 128 на фото. ΔE2000 серых до него: 116 — 4,72; 120 — 3,12; 124 — 1,54.
CatalogColor _floss(String brand, String code, int grey) => catalogColor(
  code,
  'Серый $code',
  '#${grey.toRadixString(16).padLeft(2, '0') * 3}',
  brand: brand,
  material: CatalogMaterial.floss,
);

PaletteConstraint _constraint(int dmcGrey, int anchorGrey, {double? penalty}) => PaletteConstraint.catalog(
  <CatalogColor>[_floss('DMC', '1', dmcGrey), _floss('Anchor', '2', anchorGrey)],
  material: CatalogMaterial.floss,
  preferredBrand: 'DMC',
  foreignPenaltyDeltaE: penalty ?? PaletteConstraint.defaultForeignPenaltyDeltaE,
);

typedef _Build = List<PaletteEntry> Function(PaletteConstraint constraint);

String _brandsOf(List<PaletteEntry> palette) => palette.map((e) => e.catalog!.brand).join(',');

void main() {
  final SourceImage grey = blockImage(<List<int>>[
    <int>[0x808080, 0x808080],
    <int>[0x808080, 0x808080],
  ], block: 6);

  List<PaletteEntry> t24(PaletteConstraint constraint) => const ImageToGridPipeline()
      .run(
        ImageToGridRequest(
          image: grey,
          geometry: const GridGeometry.rectangular(),
          metrics: const FakeCellMetrics(1, 1),
          columns: 2,
          rows: 2,
          maxColors: 1,
          constraint: constraint,
        ),
      )
      .palette;

  List<PaletteEntry> pixel(PaletteConstraint constraint) => const AccentPaletteBuilder().build(
    PaletteRequest(
      work: WorkImage.fromSource(
        image: grey,
        geometry: const GridGeometry.rectangular(),
        metrics: const FakeCellMetrics(1, 1),
        columns: 2,
        rows: 2,
      ),
      maxColors: 1,
      constraint: constraint,
    ),
  );

  group('приоритет основного бренда (T86)', () {
    for (final (String name, _Build run) in <(String, _Build)>[
      ('путь T24 («Как на фото»)', t24),
      ('пиксельный путь', pixel),
    ]) {
      group(name, () {
        test('чужая нитка ближе меньше чем на 3 ΔE: берётся основная', () {
          expect(_brandsOf(run(_constraint(120, 124))), 'DMC');
        });

        test('чужая нитка ближе больше чем на 3 ΔE: берётся чужая', () {
          expect(_brandsOf(run(_constraint(116, 124))), 'Anchor');
        });

        test('без основного бренда все нитки равноправны', () {
          final PaletteConstraint equal = PaletteConstraint.catalog(
            <CatalogColor>[_floss('DMC', '1', 120), _floss('Anchor', '2', 124)],
            material: CatalogMaterial.floss,
          );
          expect(_brandsOf(run(equal)), 'Anchor');
        });

        test('штраф настраивается', () {
          expect(_brandsOf(run(_constraint(120, 124, penalty: 1))), 'Anchor');
        });
      });
    }

    test('только основной бренд в списке: чужого в палитре нет', () {
      final PaletteConstraint dmcOnly = PaletteConstraint.catalog(
        <CatalogColor>[_floss('DMC', '1', 116)],
        material: CatalogMaterial.floss,
        brands: const <String>{'DMC'},
      );
      expect(_brandsOf(t24(dmcOnly)), 'DMC');
    });
  });

  group('PaletteConstraint: чужие бренды', () {
    test('штраф только у позиций не основного бренда; у позиций вне каталога его нет', () {
      final PaletteConstraint c = _constraint(120, 124);
      expect(c.foreignPenaltyDeltaE, 3);
      expect(c.penaltyOf(c.candidates![0]), 0);
      expect(c.penaltyOf(c.candidates![1]), 3);
      expect(c.penaltyOf(const PaletteEntry(rgb: Rgb(1, 2, 3))), 0);
      expect(const PaletteConstraint.free().matcher(), isNull);
    });

    test('матчер добавляет штраф к расстоянию', () {
      final PaletteConstraint c = _constraint(120, 124);
      final List<ColorMatch<PaletteEntry>> near = c.matcher()!.nearest(const Rgb(128, 128, 128));
      expect(near.first.item.catalog!.brand, 'DMC');
      expect(near.last.deltaE, closeTo(1.538 + 3, 0.01));
    });

    test('равенство учитывает основной бренд и штраф', () {
      expect(_constraint(120, 124), _constraint(120, 124));
      expect(_constraint(120, 124), isNot(_constraint(120, 124, penalty: 2)));
      expect(
        PaletteConstraint.list(_constraint(120, 124).candidates!),
        isNot(_constraint(120, 124)),
      );
    });
  });

  group('ImageToGridSettings.otherBrands (T86)', () {
    final List<CatalogColor> floss = <CatalogColor>[
      _floss('DMC', '310', 0),
      _floss('Anchor', '403', 10),
      _floss('Гамма', '0001', 20),
      catalogColor('DB0010', 'Бусина', '#FF0000'),
    ];
    const ImageToGridSettings stitch = ImageToGridSettings(technique: Technique.crossStitch);

    test('по умолчанию выключено и входит в copyWith и props', () {
      expect(stitch.otherBrands, isFalse);
      expect(stitch.copyWith(otherBrands: true).otherBrands, isTrue);
      expect(stitch.copyWith(otherBrands: true), isNot(stitch));
    });

    test('выключено: только основной бренд', () {
      expect(stitch.catalogFor(floss, brand: 'DMC').map((c) => c.code), <String>['310']);
    });

    test('включено: основной бренд и все остальные мулине, без бисера', () {
      expect(
        stitch.copyWith(otherBrands: true).catalogFor(floss, brand: 'DMC').map((c) => c.code),
        <String>['310', '403', '0001'],
      );
    });

    test('запрос получает основной бренд; без бренда, с запасом и у бисера переключатель не действует', () {
      final ImageToGridSettings on = stitch.copyWith(otherBrands: true);
      expect(on.toRequest(image: grey, catalog: floss, brand: 'DMC').constraint.preferredBrand, 'DMC');
      expect(stitch.toRequest(image: grey, catalog: floss, brand: 'DMC').constraint.preferredBrand, isNull);
      expect(on.usesOtherBrands(''), isFalse);
      expect(on.copyWith(onlyStash: true).usesOtherBrands('DMC'), isFalse);
      expect(
        on.copyWith(technique: Technique.loom).usesOtherBrands('DMC'),
        isFalse,
      );
      expect(on.toRequest(image: grey, catalog: floss, brand: 'DMC').constraint.candidates, hasLength(3));
    });
  });

  test('CatalogRef в палитре: бренд сохраняется у чужой нитки', () {
    final PaletteEntry entry = t24(_constraint(116, 124)).single;
    expect(entry.catalog!.ref, const CatalogRef(brand: 'Anchor', code: '2'));
  });
}
