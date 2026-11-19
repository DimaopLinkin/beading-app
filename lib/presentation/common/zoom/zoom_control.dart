import 'dart:math' as math;

import 'package:beading/presentation/common/zoom/canvas_zoom.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';

/// Стеклянная панель масштаба: «−», ползунок (логарифмический), «+» и процент (100% = вся схема в окне).
class ZoomControl extends StatelessWidget {
  const ZoomControl({required this.zoom, required this.viewport, super.key});

  final CanvasZoom zoom;
  final Size viewport;

  /// Положение ползунка 0..1 для масштаба [scale] между [min] и [max] (логарифм: шаги ощущаются равными).
  @visibleForTesting
  static double sliderValue(double scale, double min, double max) {
    if (max <= min) {
      return 0;
    }
    return (math.log(scale / min) / math.log(max / min)).clamp(0.0, 1.0);
  }

  @visibleForTesting
  static double scaleAt(double value, double min, double max) => min * math.pow(max / min, value).toDouble();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return AnimatedBuilder(
      animation: zoom.controller,
      builder: (context, _) {
        final double min = math.min(zoom.minScale, zoom.maxScale);
        final double max = zoom.maxScale;
        final double scale = zoom.scale;
        return GlassPanel(
          density: GlassDensity.dense,
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                label: l10n.zoomOut,
                button: true,
                child: CupertinoButton(
                  key: const ValueKey<String>('zoom-out'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(32),
                  onPressed: () => zoom.zoomStep(1 / CanvasZoom.buttonStep, viewport),
                  child: const Icon(CupertinoIcons.minus, size: 18),
                ),
              ),
              SizedBox(
                width: 140,
                child: Semantics(
                  label: l10n.zoomSliderLabel,
                  child: CupertinoSlider(
                    key: const ValueKey<String>('zoom-slider'),
                    value: sliderValue(scale, min, max),
                    onChanged: (v) => zoom.zoomTo(scaleAt(v, min, max), viewport),
                  ),
                ),
              ),
              Semantics(
                label: l10n.zoomIn,
                button: true,
                child: CupertinoButton(
                  key: const ValueKey<String>('zoom-in'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(32),
                  onPressed: () => zoom.zoomStep(CanvasZoom.buttonStep, viewport),
                  child: const Icon(CupertinoIcons.plus, size: 18),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  key: const ValueKey<String>('zoom-percent'),
                  '${(scale / min * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 13, fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
