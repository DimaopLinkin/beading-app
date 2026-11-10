import 'package:beading/presentation/grid_pattern/grid_layer_cache.dart';
import 'package:flutter/widgets.dart';

/// Слой ячеек: берёт из [GridLayerCache] готовые `Picture` видимых блоков. Перерисовывается при зуме и сдвиге
/// ([TransformationController] в `repaint`), но сами блоки не перестраивает.
class GridBasePainter extends CustomPainter {
  GridBasePainter({required this.cache, required this.controller, required this.viewportSize, required this.revision})
    : super(repaint: controller);

  final GridLayerCache cache;
  final TransformationController controller;
  final Size viewportSize;

  /// Растёт при каждой смене данных слоя: по нему painter понимает, что кеш сбросили.
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final Matrix4 inverse = Matrix4.copy(controller.value)..invert();
    // Блок-запас: чтобы при быстром сдвиге по краям не мелькали пустые места.
    final Rect visible = MatrixUtils.transformRect(inverse, Offset.zero & viewportSize).inflate(32);
    cache.paintVisible(canvas, visible);
  }

  @override
  bool shouldRepaint(GridBasePainter oldDelegate) =>
      oldDelegate.cache != cache || oldDelegate.viewportSize != viewportSize || oldDelegate.revision != revision;
}
