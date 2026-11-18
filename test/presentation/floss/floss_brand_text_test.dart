import 'package:beading/data/printing/pdf_pattern_printer.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/materials/floss_brand_mix.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/presentation/floss/floss_format.dart';
import 'package:beading/presentation/l10n/app_localizations_ru.dart';
import 'package:flutter_test/flutter_test.dart';

PatternColor _color(String brand, String code) => PatternColor(
  rgb: const Rgb(10, 20, 30),
  name: 'Нитка $code',
  components: <CatalogRef>[CatalogRef(brand: brand, code: code)],
);

FlossEstimate _estimate(List<PatternColor> colors) =>
    FlossEstimator(
      fabric: Fabric.standard,
      layers: StitchLayers.empty(columns: colors.length, rows: 1),
      reserve: 0,
    ).estimate(
      Grid.fromCells(width: colors.length, height: 1, cells: <int>[for (int i = 1; i <= colors.length; i++) i]),
      PaletteSnapshot(colors),
    );

void main() {
  final AppLocalizationsRu l10n = AppLocalizationsRu();

  FlossFormat format(FlossEstimate estimate) => FlossFormat(l10n, estimate, withReserve: false);

  final FlossEstimate mixed = _estimate(<PatternColor>[
    _color('DMC', '310'),
    _color('DMC', '666'),
    _color('Anchor', '1088'),
    _color('Гамма', '3071'),
  ]);
  final FlossEstimate single = _estimate(<PatternColor>[_color('DMC', '310'), _color('DMC', '666')]);

  test('сводка по брендам: основной бренд и число ниток каждого', () {
    expect(format(mixed).brandMixText, 'Основная часть — DMC, 2 нитки; ещё 2: Anchor 1, Гамма 1');
  });

  test('склонение «нитка» по числу основного бренда', () {
    expect(l10n.flossBrandMix('DMC', 1, 1, 'Anchor 1'), 'Основная часть — DMC, 1 нитка; ещё 1: Anchor 1');
    expect(l10n.flossBrandMix('DMC', 5, 1, 'Anchor 1'), 'Основная часть — DMC, 5 ниток; ещё 1: Anchor 1');
    expect(
      l10n.flossBrandMix('DMC', 22, 9, 'Anchor 5, Гамма 4'),
      'Основная часть — DMC, 22 нитки; ещё 9: Anchor 5, Гамма 4',
    );
  });

  test('один бренд: сводки нет и текст «Поделиться» не меняется', () {
    expect(format(single).brandMixText, isNull);
    expect(format(single).shareText('Схема'), isNot(contains('Основная часть')));
  });

  test('«Поделиться»: сводка стоит после итога, у каждой нитки бренд и номер', () {
    final String text = format(mixed).shareText('Схема');
    expect(text, contains('Anchor 1088'));
    expect(text, contains('Гамма 3071'));
    expect(text, contains('Основная часть — DMC, 2 нитки; ещё 2: Anchor 1, Гамма 1'));
    expect(text.indexOf('Итого'), lessThan(text.indexOf('Основная часть')));
  });

  test('PDF: подпись легенды с теми же числами и склонением', () {
    const PdfPatternPrinter printer = PdfPatternPrinter();
    expect(
      printer.brandNote(const FlossBrandMix(main: 'DMC', mainThreads: 3, foreign: <String, int>{'Anchor': 1})),
      'Основная часть — DMC, 3 нитки; ещё 1: Anchor 1',
    );
    expect(
      printer.brandNote(
        const FlossBrandMix(main: 'DMC', mainThreads: 21, foreign: <String, int>{'Anchor': 7, 'Гамма': 2}),
      ),
      'Основная часть — DMC, 21 нитка; ещё 9: Anchor 7, Гамма 2',
    );
  });
}
