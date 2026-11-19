import 'package:beading/presentation/common/zoom/canvas_zoom.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TransformationController controller;
  late CanvasZoom zoom;

  setUp(() {
    controller = TransformationController();
    zoom = CanvasZoom(controller: controller, maxScale: 10)..minScale = 0.5;
  });

  test('масштаб не уходит ниже минимума и выше максимума', () {
    zoom.transform(Offset.zero, 0.001, Offset.zero);
    expect(zoom.scale, closeTo(0.5, 1e-9));
    zoom.transform(Offset.zero, 1e6, Offset.zero);
    expect(zoom.scale, closeTo(10, 1e-9));
  });

  test('щипок смягчён: удвоение пальцев даёт меньше чем ×2', () {
    expect(CanvasZoom.dampPinch(2), lessThan(1.5));
    expect(CanvasZoom.dampPinch(1), 1);
    expect(CanvasZoom.dampPinch(0.5), greaterThan(0.7));
  });

  test('жест трекпада использует приращение, а не накопленный масштаб', () {
    zoom.minScale = 0.01;
    zoom.panZoomStart();
    for (final double s in <double>[1.1, 1.2, 1.3, 1.4, 1.5]) {
      zoom.panZoomUpdate(PointerPanZoomUpdateEvent(scale: s));
    }
    // Накопленный 1.5 → ровно один смягчённый шаг 1.5, а не произведение пяти.
    expect(zoom.scale, closeTo(CanvasZoom.dampPinch(1.5), 1e-6));
  });

  test('колесо: один щелчок не больше шага, вверх приближает', () {
    expect(CanvasZoom.wheelFactor(-100), greaterThan(1));
    expect(CanvasZoom.wheelFactor(100), lessThan(1));
    expect(CanvasZoom.wheelFactor(100000), CanvasZoom.wheelFactor(1e9));
    expect(CanvasZoom.wheelFactor(-1e9), closeTo(CanvasZoom.wheelMaxStep, 1e-9));
    zoom.signal(const PointerScrollEvent(scrollDelta: Offset(0, -50)));
    expect(zoom.scale, greaterThan(1));
  });

  test('колесо не двигает полотно', () {
    zoom.signal(const PointerScrollEvent(scrollDelta: Offset(0, 40)));
    expect(controller.value.getTranslation().x, 0);
  });

  test('средняя кнопка мыши двигает полотно, левая не забирается', () {
    expect(
      zoom.middleDown(
        const PointerDownEvent(
          pointer: 1,
          kind: PointerDeviceKind.mouse,
        ),
      ),
      isFalse,
    );
    expect(
      zoom.middleDown(const PointerDownEvent(pointer: 2, kind: PointerDeviceKind.mouse, buttons: kMiddleMouseButton)),
      isTrue,
    );
    expect(
      zoom.middleMove(const PointerMoveEvent(pointer: 2, delta: Offset(12, -5), buttons: kMiddleMouseButton)),
      isTrue,
    );
    expect(controller.value.getTranslation().x, 12);
    expect(controller.value.getTranslation().y, -5);
    expect(zoom.middleEnd(const PointerUpEvent(pointer: 2)), isTrue);
    expect(zoom.middleMove(const PointerMoveEvent(pointer: 2, delta: Offset(1, 1))), isFalse);
  });

  test('кнопки зумят вокруг центра окна с границами', () {
    zoom.zoomStep(CanvasZoom.buttonStep, const Size(200, 100));
    expect(zoom.scale, closeTo(CanvasZoom.buttonStep, 1e-9));
    final Offset center = MatrixUtils.transformPoint(controller.value, const Offset(100, 50));
    expect(center.dx, closeTo(100, 1e-6));
    expect(center.dy, closeTo(50, 1e-6));
    zoom.zoomTo(0.001, const Size(200, 100));
    expect(zoom.scale, closeTo(0.5, 1e-9));
  });
}
