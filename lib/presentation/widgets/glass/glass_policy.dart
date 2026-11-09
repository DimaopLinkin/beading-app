import 'package:flutter/widgets.dart';

/// Когда стекло нужно заменить непрозрачной заливкой.
///
/// Flutter не сообщает системную настройку «Уменьшить прозрачность», поэтому флаг [reduceTransparency] выставляется
/// платформенным слоем (см. changelog T01g) и по умолчанию выключен. «Повышенная контрастность» приходит от самой
/// системы через `MediaQuery.highContrast`.
class GlassPolicy extends InheritedWidget {
  const GlassPolicy({required this.reduceTransparency, required super.child, super.key});

  final bool reduceTransparency;

  /// Нужна ли непрозрачная заливка вместо размытия фона.
  static bool isOpaque(BuildContext context) {
    final GlassPolicy? policy = context.dependOnInheritedWidgetOfExactType<GlassPolicy>();
    return (policy?.reduceTransparency ?? false) || (MediaQuery.maybeHighContrastOf(context) ?? false);
  }

  @override
  bool updateShouldNotify(GlassPolicy oldWidget) => reduceTransparency != oldWidget.reduceTransparency;
}
