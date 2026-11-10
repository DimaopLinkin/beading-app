import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Расширяет область [child] до `tokens.minTapTarget` (44 pt), не растягивая её сверх этого.
///
/// Оборачивайте внутрь обработчика касаний с `HitTestBehavior.opaque`, чтобы пустая часть области тоже ловила нажатие.
class MinTapTarget extends StatelessWidget {
  const MinTapTarget({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double min = context.tokens.minTapTarget;
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: min, minHeight: min),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
