import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Сообщает фактическую высоту потомка после раскладки.
///
/// Нужен там, где полотно занимает всё место над нижней панелью: угаданная константа высоты панели даёт пустую
/// полосу над ней, когда панель оказывается ниже.
class MeasuredHeight extends SingleChildRenderObjectWidget {
  const MeasuredHeight({required this.onChange, required Widget super.child, super.key});

  final ValueChanged<double> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasuredHeight(onChange);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderMeasuredHeight).onChange = onChange;
}

class _RenderMeasuredHeight extends RenderProxyBox {
  _RenderMeasuredHeight(this.onChange);

  ValueChanged<double> onChange;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final double height = size.height;
    if (height != _last) {
      _last = height;
      WidgetsBinding.instance.addPostFrameCallback((_) => onChange(height));
    }
  }
}
