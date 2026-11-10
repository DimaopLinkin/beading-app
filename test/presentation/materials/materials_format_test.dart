import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/materials/bead_estimate.dart';
import 'package:beading/presentation/l10n/app_localizations_ru.dart';
import 'package:beading/presentation/materials/materials_format.dart';
import 'package:flutter_test/flutter_test.dart';

import 'materials_fixtures.dart';

void main() {
  final AppLocalizationsRu l10n = AppLocalizationsRu();

  MaterialsFormat format({required bool withReserve}) =>
      MaterialsFormat(l10n, handWrittenEstimate(), withReserve: withReserve);

  test('текст «Поделиться» по эталону: количество по схеме', () {
    const String expected =
        'Материалы: Браслет Ёлка\n'
        'Бисер Delica 11/0\n'
        '\n'
        '1. A Miyuki Delica DB0010 Красный — 1\u00A0240 шт, 6,2 г\n'
        '2. B DMC 310 + DMC 666 Смесь — 36 шт, 0,2 г\n'
        '3. Toho 41 Белый — 4 шт, <\u00A00,1 г\n'
        '\n'
        'Итого: 1\u00A0280 шт, 6,4 г\n'
        'Вес приблизительный.';

    expect(format(withReserve: false).shareText('Браслет Ёлка'), expected);
  });

  test('текст «Поделиться» по эталону: с запасом 10%', () {
    const String expected =
        'Материалы: Браслет Ёлка\n'
        'Бисер Delica 11/0\n'
        '\n'
        '1. A Miyuki Delica DB0010 Красный — 1\u00A0364 шт, 6,8 г\n'
        '2. B DMC 310 + DMC 666 Смесь — 40 шт, 0,2 г\n'
        '3. Toho 41 Белый — 5 шт, <\u00A00,1 г\n'
        '\n'
        'Итого: 1\u00A0409 шт, 7,0 г\n'
        'Количество указано с запасом 10%.\n'
        'Вес приблизительный.';

    expect(format(withReserve: true).shareText('Браслет Ёлка'), expected);
  });

  test('название размера: Delica и рокайль', () {
    final BeadEstimate rocaille = BeadEstimate(
      beadSize: BeadSize.rocaille8,
      reserve: 0.1,
      lines: const <BeadMaterialLine>[],
    );

    expect(format(withReserve: false).beadSizeLabel, 'Delica 11/0');
    expect(MaterialsFormat(l10n, rocaille, withReserve: false).beadSizeLabel, 'рокайль 8/0');
  });

  test('артикул: бренд и код; у смешанной нити обе позиции', () {
    final MaterialsFormat f = format(withReserve: false);

    expect(f.articleLabel(handWrittenEstimate().lines[0].color), 'Miyuki Delica DB0010');
    expect(f.articleLabel(handWrittenEstimate().lines[1].color), 'DMC 310 + DMC 666');
  });

  test('итоги и проценты запаса', () {
    final MaterialsFormat f = format(withReserve: true);

    expect(f.reservePercent, 10);
    expect(f.totalPieces, 1409);
    expect(f.totalGrams, closeTo(7.045, 1e-9));
  });

  test('вес меньше одной двадцатой грамма — «< 0,1 г», ноль — «0,0 г»', () {
    final MaterialsFormat f = format(withReserve: false);

    expect(f.gramsText(0.049), '<\u00A00,1 г');
    expect(f.gramsText(0.05), '0,1 г');
    expect(f.gramsText(0), '0,0 г');
  });
}
