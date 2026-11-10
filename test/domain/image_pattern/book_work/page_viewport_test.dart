import 'package:beading/domain/image_pattern/book_work/page_viewport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Окно 800, сверху панель 100, снизу панель 200: видно 100…600. Страница в масштабе 1 высотой 3000.
  PageViewport reveal(PageViewport view, {required double top, required double bottom}) => view.revealing(
    rulerTop: top,
    rulerBottom: bottom,
    viewHeight: 800,
    contentHeight: 3000,
    topInset: 100,
    bottomInset: 200,
  );

  test('видимая линейка не двигает вид', () {
    const PageViewport view = PageViewport(scale: 2, dx: -10, dy: -300);
    expect(reveal(view, top: 300, bottom: 320), view);
  });

  test('линейка под нижней панелью: вид сдвигается, масштаб и dx не меняются', () {
    const PageViewport view = PageViewport(scale: 2, dx: -10, dy: 0);
    final PageViewport result = reveal(view, top: 900, bottom: 940);
    expect(result.scale, 2);
    expect(result.dx, -10);
    final double screenTop = result.scale * 900 + result.dy;
    expect(screenTop, closeTo(100 + 500 / 3, 1e-9));
  });

  test('линейка над верхней панелью: вид сдвигается вниз', () {
    const PageViewport view = PageViewport(scale: 2, dx: 0, dy: -1000);
    final PageViewport result = reveal(view, top: 100, bottom: 140);
    expect(result.scale * 100 + result.dy, greaterThanOrEqualTo(100));
    expect(result.scale * 140 + result.dy, lessThanOrEqualTo(600));
  });

  test('вид не уезжает за верх страницы', () {
    const PageViewport view = PageViewport(scale: 1, dx: 0, dy: -500);
    final PageViewport result = reveal(view, top: 0, bottom: 30);
    expect(result.dy, 100);
  });

  test('вид не уезжает за низ страницы', () {
    final PageViewport result = reveal(PageViewport.identity, top: 2990, bottom: 3000);
    // низ страницы (3000 + dy) упирается в нижнюю границу видимой области (600)
    expect(3000 + result.dy, 600);
  });
}
