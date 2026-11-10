import 'package:beading/domain/image_pattern/book_work/pattern_zone.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const double page = 1000;
  const double width = 600;
  const PatternZone zone = PatternZone(top: 200, bottom: 800, left: 50, right: 550);

  RulerState fresh({RowDirection direction = RowDirection.topDown}) =>
      RulerState.initial(page, direction: direction).withZone(zone, page, imageWidth: width);

  group('PatternZone', () {
    test('fitted оставляет зону внутри страницы и не тоньше минимума', () {
      const PatternZone wild = PatternZone(top: -50, bottom: 1500, left: -10, right: 900);
      final PatternZone fixed = wild.fitted(height: page, width: width);
      expect(fixed, const PatternZone(top: 0, bottom: page, left: 0, right: width));
      const PatternZone thin = PatternZone(top: 500, bottom: 500, left: 10, right: 10);
      final PatternZone thick = thin.fitted(height: page, width: width);
      expect(thick.height, PatternZone.minSpan);
      expect(thick.width, PatternZone.minSpan);
    });
  });

  group('зона без числа рядов', () {
    test('линейка встаёт к верху зоны, а не страницы', () {
      expect(fresh().top, 200);
      expect(fresh().row, 1);
    });

    test('снизу вверх встаёт к низу зоны', () {
      final RulerState up = fresh(direction: RowDirection.bottomUp);
      expect(up.bottom, 800);
    });

    test('шаг не выводит линейку за низ зоны', () {
      RulerState r = fresh().withHeight(100, page);
      for (int i = 0; i < 20; i++) {
        r = r.next(page);
      }
      expect(r.bottom, 800);
      expect(r.row, 6);
      expect(r.isLastRow(page), isTrue);
      expect(r.canAdvance(page), isFalse);
    });

    test('назад не выше верха зоны', () {
      RulerState r = fresh().withHeight(100, page).next(page);
      r = r.previous(page).previous(page);
      expect(r.top, 200);
      expect(r.row, 1);
      expect(r.canRetreat(page), isFalse);
    });

    test('снизу вверх идёт до верха зоны', () {
      RulerState r = fresh(direction: RowDirection.bottomUp).withHeight(100, page);
      for (int i = 0; i < 20; i++) {
        r = r.next(page);
      }
      expect(r.top, 200);
      expect(r.isLastRow(page), isTrue);
    });

    test('высота не больше зоны', () {
      expect(fresh().withHeight(900, page).height, 600);
    });

    test('смена зоны на первом ряду переставляет линейку, после первого ряда не двигает', () {
      final RulerState moved = fresh().withHeight(100, page).next(page);
      final RulerState shifted = moved.withZone(zone.copyWith(top: 100), page);
      expect(shifted.top, moved.top);
      final RulerState first = fresh().withZone(zone.copyWith(top: 300), page);
      expect(first.top, 300);
    });

    test('без зоны всё как раньше', () {
      expect(RulerState.initial(page).zone, isNull);
      expect(RulerState.initial(page).withoutZone(page).top, 0);
    });

    test('withoutZone возвращает всю страницу и убирает число рядов', () {
      final RulerState r = fresh().withRowCount(10, page).withoutZone(page);
      expect(r.zone, isNull);
      expect(r.rowCount, isNull);
    });
  });

  group('зона с числом рядов', () {
    test('высота и шаг считаются сами', () {
      final RulerState r = fresh().withRowCount(12, page);
      expect(r.height, 50);
      expect(r.step, 50);
      expect(r.top, 200);
      expect(r.rowCount, 12);
    });

    test('ровно столько рядов, сколько задано, без накопления погрешности', () {
      RulerState r = fresh().withRowCount(7, page);
      for (int i = 0; i < 30; i++) {
        r = r.next(page);
      }
      expect(r.row, 7);
      expect(r.bottom, closeTo(800, 1e-9));
      expect(r.isLastRow(page), isTrue);
    });

    test('назад возвращает на тот же ряд', () {
      RulerState r = fresh().withRowCount(7, page);
      r = r.next(page).next(page).previous(page);
      expect(r.row, 2);
      expect(r.top, closeTo(200 + 600 / 7, 1e-9));
    });

    test('снизу вверх первый ряд у низа зоны', () {
      final RulerState up = fresh(direction: RowDirection.bottomUp).withRowCount(6, page);
      expect(up.bottom, 800);
      expect(up.next(page).bottom, closeTo(700, 1e-9));
    });

    test('смена числа рядов в середине работы оставляет тот же номер ряда', () {
      RulerState r = fresh().withRowCount(10, page).next(page).next(page);
      r = r.withRowCount(20, page);
      expect(r.row, 3);
      expect(r.top, closeTo(200 + 2 * 30, 1e-9));
    });

    test('номер ряда не больше числа рядов', () {
      RulerState r = fresh().withRowCount(10, page);
      for (int i = 0; i < 9; i++) {
        r = r.next(page);
      }
      expect(r.withRowCount(4, page).row, 4);
    });

    test('рядов не больше, чем помещается линейки минимальной высоты', () {
      expect(fresh().withRowCount(100000, page).rowCount, 150);
      expect(fresh().withRowCount(0, page).rowCount, 1);
    });

    test('смена зоны пересчитывает высоту и шаг', () {
      final RulerState r = fresh().withRowCount(10, page).withZone(zone.copyWith(bottom: 400), page);
      expect(r.height, 20);
      expect(r.step, 20);
    });

    test('ручная высота или шаг снимают число рядов', () {
      expect(fresh().withRowCount(10, page).withHeight(30, page).rowCount, isNull);
      expect(fresh().withRowCount(10, page).withStep(30, page).rowCount, isNull);
    });

    test('withRowCount(null) оставляет линейку как есть и снимает число', () {
      final RulerState r = fresh().withRowCount(10, page);
      final RulerState cleared = r.withRowCount(null, page);
      expect(cleared.rowCount, isNull);
      expect(cleared.height, r.height);
    });

    test('число рядов работает и без зоны: считает от всей страницы', () {
      final RulerState r = RulerState.initial(page).withRowCount(50, page);
      expect(r.height, 20);
    });

    test('fit подгоняет зону к меньшей странице', () {
      final RulerState r = fresh().withRowCount(10, page).fit(500, imageWidth: 300);
      expect(r.zone!.bottom, 500);
      expect(r.zone!.right, 300);
      expect(r.height, 30);
    });
  });
}
