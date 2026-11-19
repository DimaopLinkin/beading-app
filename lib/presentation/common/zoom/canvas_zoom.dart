import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Общая логика зума полотна схемы (вышивка, редактор): границы, чувствительность жестов, колесо и средняя кнопка
/// мыши, шаг кнопок. Окно с матрицей — [controller]; события приходят из `Listener` полотна.
class CanvasZoom {
  CanvasZoom({required this.controller, required this.maxScale});

  /// Щипок на трекпаде: показатель степени для коэффициента (меньше 1 — мягче, чем пальцы по экрану).
  static const double pinchExponent = 0.45;

  /// Колесо мыши: коэффициент `exp(-delta * k)` на пиксель прокрутки.
  static const double wheelRate = 0.0012;

  /// Один щелчок колеса не меняет масштаб сильнее чем в столько раз.
  static const double wheelMaxStep = 1.15;

  /// Шаг кнопок «+» и «−».
  static const double buttonStep = 1.25;

  final TransformationController controller;

  /// Верхняя граница масштаба.
  final double maxScale;

  /// Нижняя граница: вся схема помещается в окно. Задаётся при раскладке.
  double minScale = 0.05;

  int? _panPointer;
  double _lastPanZoomScale = 1;

  /// Текущий масштаб матрицы.
  double get scale => controller.value.storage[0];

  /// Масштаб в границах [minScale]..[maxScale].
  double clamp(double value) => value.clamp(math.min(minScale, maxScale), maxScale);

  /// Коэффициент для щипка трекпада с кумулятивным [scale] жеста, смягчённый.
  static double dampPinch(double factor) => math.pow(factor, pinchExponent).toDouble();

  /// Коэффициент зума от прокрутки колесом: вниз — отдалить, вверх — приблизить.
  static double wheelFactor(double scrollDy) => math.exp(-scrollDy * wheelRate).clamp(1 / wheelMaxStep, wheelMaxStep);

  /// Масштаб вокруг [focal] и сдвиг [pan] в координатах экрана; зум ограничен.
  void transform(Offset focal, double factor, Offset pan) {
    final Matrix4 current = controller.value;
    final double now = current.storage[0];
    final double k = clamp(now * factor) / now;
    controller.value = Matrix4.identity()
      ..translateByDouble(pan.dx, pan.dy, 0, 1)
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
      ..multiply(current);
  }

  /// Кнопки и ползунок: зум вокруг центра окна [viewport].
  void zoomTo(double target, Size viewport) =>
      transform(viewport.center(Offset.zero), clamp(target) / scale, Offset.zero);

  void zoomStep(double factor, Size viewport) => zoomTo(scale * factor, viewport);

  void panZoomStart() => _lastPanZoomScale = 1;

  /// Жест двумя пальцами по трекпаду: у события `scale` накопленный с начала жеста, `panDelta` — приращение.
  void panZoomUpdate(PointerPanZoomUpdateEvent e) {
    final double step = _lastPanZoomScale == 0 ? 1 : e.scale / _lastPanZoomScale;
    _lastPanZoomScale = e.scale;
    transform(e.localPosition, dampPinch(step), e.panDelta);
  }

  /// Колесо мыши зумит вокруг указателя; щипок macOS (`PointerScaleEvent`) тоже.
  void signal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      transform(e.localPosition, wheelFactor(e.scrollDelta.dy), Offset.zero);
    } else if (e is PointerScaleEvent) {
      transform(e.localPosition, dampPinch(e.scale), Offset.zero);
    }
  }

  /// Нажата средняя кнопка мыши: полотно едет за указателем. Возвращает true, если событие забрано.
  bool middleDown(PointerDownEvent e) {
    if (e.kind == PointerDeviceKind.mouse && e.buttons == kMiddleMouseButton) {
      _panPointer = e.pointer;
      return true;
    }
    return false;
  }

  bool middleMove(PointerMoveEvent e) {
    if (e.pointer != _panPointer) {
      return false;
    }
    transform(e.localPosition, 1, e.delta);
    return true;
  }

  bool middleEnd(PointerEvent e) {
    if (e.pointer != _panPointer) {
      return false;
    }
    _panPointer = null;
    return true;
  }
}
