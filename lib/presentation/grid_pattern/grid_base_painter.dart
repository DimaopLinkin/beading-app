import 'package:beading/presentation/grid_pattern/grid_layer_cache.dart';
import 'package:flutter/widgets.dart';

/// Слой ячеек: берёт из [GridLayerCache] готовые `Picture` видимых блоков. Перерисовывается при зуме и сдвиге
/// ([TransformationController] в `repaint`), но сами блоки не перестраивает.
class GridBasePainter extends CustomPainter {
  GridBasePainter({
    required this.cache,
    required this.controller,
    required this.viewportSize,
    required this.revision,
    this.wholeScene = false,
    this.fittedScale = 1,
    this.devicePixelRatio = 1,
  }) : super(repaint: Listenable.merge(<Listenable>[controller, cache.overviewChanged]));

  final GridLayerCache cache;
  final TransformationController controller;
  final Size viewportSize;

  /// Растёт при каждой смене данных слоя: по нему painter понимает, что кеш сбросили.
  final int revision;

  /// Рисовать всю схему, а не видимую часть (неинтерактивный режим: вид масштабирует `FittedBox`, а не контроллер).
  final bool wholeScene;

  /// Масштаб `FittedBox` в неинтерактивном режиме (в интерактивном масштаб берётся из контроллера).
  final double fittedScale;

  /// Физических пикселей в логическом: вместе с масштабом даёт размер клетки на экране.
  final double devicePixelRatio;

  double _devicePxPerCell(double scale) {
    final Size cell = cache.cellSize;
    return (cell.width < cell.height ? cell.width : cell.height) * scale * devicePixelRatio;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (wholeScene) {
      cache.paintVisible(canvas, Offset.zero & size, devicePxPerCell: _devicePxPerCell(fittedScale));
      return;
    }
    final Matrix4 inverse = Matrix4.copy(controller.value)..invert();
    // Блок-запас: чтобы при быстром сдвиге по краям не мелькали пустые места.
    final Rect visible = MatrixUtils.transformRect(inverse, Offset.zero & viewportSize).inflate(32);
    cache.paintVisible(canvas, visible, devicePxPerCell: _devicePxPerCell(controller.value.getMaxScaleOnAxis()));
  }

  @override
  bool shouldRepaint(GridBasePainter oldDelegate) =>
      oldDelegate.cache != cache ||
      oldDelegate.viewportSize != viewportSize ||
      oldDelegate.revision != revision ||
      oldDelegate.wholeScene != wholeScene ||
      oldDelegate.fittedScale != fittedScale ||
      oldDelegate.devicePixelRatio != devicePixelRatio;
}
