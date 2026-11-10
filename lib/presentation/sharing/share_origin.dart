import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:flutter/widgets.dart';

/// Прямоугольник виджета [context] в координатах окна: от него лист «Поделиться» открывается на iPad и macOS.
/// Пока виджет не отрисован — `null`.
ShareOrigin? shareOriginOf(BuildContext context) {
  final RenderObject? box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) {
    return null;
  }
  final Offset topLeft = box.localToGlobal(Offset.zero);
  return ShareOrigin(left: topLeft.dx, top: topLeft.dy, width: box.size.width, height: box.size.height);
}
