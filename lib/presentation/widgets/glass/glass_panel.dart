import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';

/// Плавающая стеклянная панель над контентом: панель инструментов, баннер, подсказка.
class GlassPanel extends StatelessWidget {
  const GlassPanel({required this.child, this.density = GlassDensity.regular, this.padding, super.key});

  final Widget child;
  final GlassDensity density;

  /// По умолчанию — `spacing.l` со всех сторон.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return GlassSurface(
      density: density,
      shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(tokens.radius.l)),
      child: Padding(padding: padding ?? EdgeInsets.all(tokens.spacing.l), child: child),
    );
  }
}
