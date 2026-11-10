import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const double page = 1000;
  const RulerState ruler = RulerState(top: 100, height: 40, step: 40, highlight: RulerHighlight.green, row: 3);

  group('RulerState.initial', () {
    test('у верха страницы, шаг равен высоте, первый ряд', () {
      final RulerState initial = RulerState.initial(page);
      expect(initial.top, 0);
      expect(initial.height, 30);
      expect(initial.step, initial.height);
      expect(initial.row, 1);
      expect(initial.highlight, RulerHighlight.yellow);
    });

    test('на очень низкой странице высота не меньше минимума и не больше страницы', () {
      expect(RulerState.initial(50).height, RulerState.minHeight);
      expect(RulerState.initial(2).height, 4);
    });
  });

  group('сдвиг вниз', () {
    test('на шаг, ряд растёт', () {
      final RulerState moved = ruler.moveDown(page);
      expect(moved.top, 140);
      expect(moved.row, 4);
    });

    test('у нижней границы останавливается ровно на краю страницы', () {
      final RulerState near = ruler.moveDown(page);
      const RulerState almost = RulerState(top: 950, height: 40, step: 40, highlight: RulerHighlight.yellow, row: 9);
      expect(near.canMoveDown(page), isTrue);
      final RulerState last = almost.moveDown(page);
      expect(last.top, 960);
      expect(last.bottom, page);
      expect(last.row, 10);
    });

    test('внизу страницы не двигается и ряд не растёт', () {
      const RulerState bottom = RulerState(top: 960, height: 40, step: 40, highlight: RulerHighlight.yellow, row: 9);
      expect(bottom.canMoveDown(page), isFalse);
      expect(bottom.moveDown(page), bottom);
    });
  });

  group('сдвиг вверх', () {
    test('на шаг, ряд убывает', () {
      final RulerState moved = ruler.moveUp();
      expect(moved.top, 60);
      expect(moved.row, 2);
    });

    test('у верха останавливается на нуле', () {
      const RulerState low = RulerState(top: 10, height: 40, step: 40, highlight: RulerHighlight.yellow, row: 2);
      final RulerState moved = low.moveUp();
      expect(moved.top, 0);
      expect(moved.row, 1);
      expect(moved.canMoveUp, isFalse);
    });

    test('вверху страницы не двигается, ряд не уходит ниже первого', () {
      final RulerState initial = RulerState.initial(page);
      expect(initial.moveUp(), initial);
    });

    test('ряд не меньше 1, даже если сдвиг вверх сделан с ряда 1 не с верха', () {
      const RulerState odd = RulerState(top: 100, height: 40, step: 40, highlight: RulerHighlight.yellow, row: 1);
      expect(odd.moveUp().row, 1);
    });
  });

  group('смена шага, высоты и цвета', () {
    test('шаг применяется к следующему сдвигу', () {
      final RulerState moved = ruler.withStep(10, page).moveDown(page);
      expect(moved.top, 110);
    });

    test('шаг ограничен снизу единицей и сверху высотой страницы', () {
      expect(ruler.withStep(0, page).step, RulerState.minStep);
      expect(ruler.withStep(5000, page).step, page);
    });

    test('высота ограничена минимумом и страницей', () {
      expect(ruler.withHeight(1, page).height, RulerState.minHeight);
      expect(ruler.withHeight(5000, page).height, page);
    });

    test('рост высоты у низа страницы поднимает линейку, чтобы она не вышла за край', () {
      const RulerState bottom = RulerState(top: 960, height: 40, step: 40, highlight: RulerHighlight.yellow, row: 9);
      final RulerState taller = bottom.withHeight(100, page);
      expect(taller.top, 900);
      expect(taller.bottom, page);
    });

    test('цвет подсветки меняется, остальное — нет', () {
      final RulerState recolored = ruler.withHighlight(RulerHighlight.pink);
      expect(recolored.highlight, RulerHighlight.pink);
      expect(recolored.top, ruler.top);
      expect(recolored.row, ruler.row);
    });
  });

  test('fit приводит линейку к странице меньшего размера', () {
    final RulerState fitted = ruler.fit(120);
    expect(fitted.bottom, lessThanOrEqualTo(120));
    expect(fitted.top, 80);
  });
}
