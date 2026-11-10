import 'dart:ui';

import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_policy.dart';
import 'package:flutter/cupertino.dart';

/// Какие токены стекла взять: мелкие поверхности и плавающие панели или бары и листы.
enum GlassMaterial { surface, bar }

/// Плотность тонировки. [dense] — для текста и иконок поверх ярких цветов бусин.
enum GlassDensity { regular, dense }

/// Основа всех стеклянных виджетов: размытие фона, тонировка, блик и тонкая граница.
///
/// Это приближение Liquid Glass без преломления (ADR-0002). Не ставьте стекло на стекло и не накрывайте им схему и фото:
/// стекло — только слой управления.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.shape,
    required this.child,
    this.material = GlassMaterial.surface,
    this.density = GlassDensity.regular,
    super.key,
  });

  final OutlinedBorder shape;
  final Widget child;
  final GlassMaterial material;
  final GlassDensity density;

  /// `CupertinoDynamicColor` не равен обычному `Color` с тем же значением; отдаём простой цвет.
  static Color _plain(Color color) => Color(color.toARGB32());

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final GlassTokens glass = material == GlassMaterial.surface ? tokens.glassSurface : tokens.glassBar;
    final bool opaque = GlassPolicy.isOpaque(context);

    final bool dense = density == GlassDensity.dense;
    final Color fill = _plain(
      CupertinoDynamicColor.resolve(
        opaque
            ? (dense ? glass.opaqueDenseFill : glass.opaqueFill)
            : dense
            ? glass.denseTint
            : glass.tint,
        context,
      ),
    );
    final Color border = _plain(
      CupertinoDynamicColor.resolve(
        opaque ? (dense ? glass.opaqueDenseBorder : glass.opaqueBorder) : glass.border,
        context,
      ),
    );
    final double sigma = dense ? glass.denseBlurSigma : glass.blurSigma;
    final Color highlight = _plain(CupertinoDynamicColor.resolve(glass.highlight, context));

    Widget content = DecoratedBox(
      key: const ValueKey<String>('glass-fill'),
      decoration: ShapeDecoration(
        color: fill,
        shape: shape.copyWith(
          side: BorderSide(color: border, width: opaque ? glass.opaqueBorderWidth : glass.borderWidth),
        ),
      ),
      child: opaque
          ? child
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: const Alignment(0, -0.2),
                  colors: <Color>[highlight, highlight.withAlpha(0)],
                ),
              ),
              child: child,
            ),
    );

    if (!opaque) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.clamp),
        child: content,
      );
    }

    return RepaintBoundary(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: content,
      ),
    );
  }
}
