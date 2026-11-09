import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:beading/presentation/widgets/min_tap_target.dart';
import 'package:flutter/cupertino.dart';

/// Круглая или капсульная стеклянная кнопка. Область нажатия не меньше `tokens.minTapTarget`.
///
/// [semanticLabel] обязателен: у иконки-кнопки иначе нет имени для VoiceOver. Нажатие подсвечивается накладкой, а не
/// прозрачностью: `Opacity` над `BackdropFilter` отключает размытие.
class GlassButton extends StatefulWidget {
  const GlassButton({
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.density = GlassDensity.regular,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final GlassDensity density;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _pressed = false;

  void _setPressed({required bool value}) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final bool enabled = widget.onPressed != null;
    final Color pressOverlay = CupertinoColors.label.resolveFrom(context).withValues(alpha: 0.12);

    Widget visual = GlassSurface(
      density: widget.density,
      shape: const StadiumBorder(),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.m),
        child: Opacity(opacity: enabled ? 1 : 0.4, child: widget.child),
      ),
    );
    if (_pressed) {
      visual = Stack(
        children: <Widget>[
          visual,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey<String>('glass-button-pressed'),
                decoration: ShapeDecoration(color: pressOverlay, shape: const StadiumBorder()),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(value: true) : null,
        onTapUp: enabled ? (_) => _setPressed(value: false) : null,
        onTapCancel: enabled ? () => _setPressed(value: false) : null,
        onTap: widget.onPressed,
        child: MinTapTarget(child: visual),
      ),
    );
  }
}
