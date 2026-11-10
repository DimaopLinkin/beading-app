import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';

/// Плавающий стеклянный бар (навигация, нижние действия) в форме капсулы.
class GlassBar extends StatelessWidget {
  const GlassBar({required this.child, this.density = GlassDensity.regular, this.padding, super.key});

  final Widget child;
  final GlassDensity density;

  /// По умолчанию — `spacing.m` по вертикали и `spacing.l` по горизонтали.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return GlassSurface(
      material: GlassMaterial.bar,
      density: density,
      shape: const StadiumBorder(),
      child: Padding(
        padding: padding ?? EdgeInsets.symmetric(horizontal: tokens.spacing.l, vertical: tokens.spacing.m),
        child: child,
      ),
    );
  }
}
