import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';

/// Нижний стеклянный лист с крупными верхними скруглениями и ручкой.
class GlassSheet extends StatelessWidget {
  const GlassSheet({required this.child, this.showGrabber = true, this.floating = false, this.density = GlassDensity.regular, super.key});

  final Widget child;
  final bool showGrabber;

  /// Лист «парит» над низом экрана (iOS 26): скруглён со всех сторон, без ручки-перетаскивания.
  final bool floating;
  final GlassDensity density;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final Color grabber = CupertinoColors.tertiaryLabel.resolveFrom(context);
    return GlassSurface(
      material: GlassMaterial.bar,
      density: density,
      shape: RoundedSuperellipseBorder(
        borderRadius: floating
            ? BorderRadius.circular(tokens.radius.xl)
            : BorderRadius.vertical(top: Radius.circular(tokens.radius.xl)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(tokens.spacing.l, tokens.spacing.s, tokens.spacing.l, tokens.spacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showGrabber && !floating)
              Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.m),
                child: Center(
                  child: Container(
                    key: const ValueKey<String>('glass-sheet-grabber'),
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(color: grabber, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
