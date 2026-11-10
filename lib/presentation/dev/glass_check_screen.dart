import 'dart:ui' as ui;

import 'package:beading/presentation/dev/frame_stats.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_bar.dart';
import 'package:beading/presentation/widgets/glass/glass_button.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_policy.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Экран проверки стекла на устройстве (ADR-0002, T10): схема 100×400 под тремя стеклянными слоями, которая
/// всё время ползёт, чтобы размытие пересчитывалось каждый кадр, и счётчик времени кадров.
///
/// Показывается только в отладочных и профильных сборках. Кадры мерить только в профильной сборке.
class GlassCheckScreen extends StatefulWidget {
  const GlassCheckScreen({super.key});

  static const int columns = 100;
  static const int rows = 400;

  @override
  State<GlassCheckScreen> createState() => _GlassCheckScreenState();
}

class _GlassCheckScreenState extends State<GlassCheckScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _scroll = AnimationController(vsync: this, duration: const Duration(seconds: 12))
    ..repeat();
  final FrameStats _stats = FrameStats();
  bool _running = true;
  final Stopwatch _sinceRefresh = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _scroll.dispose();
    super.dispose();
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    if (!_running || !mounted) {
      return;
    }
    for (final ui.FrameTiming t in timings) {
      _stats.add(build: t.buildDuration, raster: t.rasterDuration);
    }
    // Не чаще раза в полсекунды: частая перерисовка самих цифр искажала бы измеряемые кадры.
    if (_sinceRefresh.elapsedMilliseconds >= 500) {
      _sinceRefresh.reset();
      setState(() {});
    }
  }

  void _togglePause() {
    setState(() {
      _running = !_running;
      if (_running) {
        _scroll.repeat();
      } else {
        _scroll.stop();
      }
      _sinceRefresh.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final bool reduce = GlassPolicy.reduceTransparencyOf(context);
    final bool contrast = MediaQuery.highContrastOf(context);
    final bool opaque = GlassPolicy.isOpaque(context);
    String onOff({required bool on}) => on ? l10n.glassCheckOn : l10n.glassCheckOff;
    String ms(double value) => value.toStringAsFixed(1);

    return CupertinoPageScaffold(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) => CustomPaint(painter: _GridPainter(_scroll.value)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.m),
              child: Column(
                children: <Widget>[
                  GlassBar(
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            l10n.glassCheckTitle,
                            style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                          ),
                        ),
                        GlassButton(
                          semanticLabel: _running ? l10n.glassCheckPause : l10n.glassCheckResume,
                          onPressed: _togglePause,
                          child: Icon(_running ? CupertinoIcons.pause : CupertinoIcons.play, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GlassPanel(
                    density: GlassDensity.dense,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(l10n.glassCheckReduceTransparency(onOff(on: reduce))),
                        Text(l10n.glassCheckHighContrast(onOff(on: contrast))),
                        Text(
                          l10n.glassCheckSurface(opaque ? l10n.glassCheckSurfaceOpaque : l10n.glassCheckSurfaceGlass),
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.glassCheckFrames(_stats.frames), key: const ValueKey<String>('glass-check-frames')),
                        Text(l10n.glassCheckAverage(ms(_stats.averageMs), ms(_stats.p95Ms), ms(_stats.worstMs))),
                        Text(l10n.glassCheckOverBudget(_stats.countOver(8.33), _stats.countOver(16.67))),
                        if (!kProfileMode)
                          Text(l10n.glassCheckProfileHint, style: const TextStyle(color: CupertinoColors.systemRed)),
                      ],
                    ),
                  ),
                  SizedBox(height: tokens.spacing.m),
                  GlassButton(
                    semanticLabel: l10n.glassCheckReset,
                    onPressed: () => setState(() {
                      _stats.reset();
                      _sinceRefresh.reset();
                    }),
                    child: Text(l10n.glassCheckReset),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Схема 100×400 из 8 цветов, сдвигается по вертикали на [progress] высоты.
class _GridPainter extends CustomPainter {
  _GridPainter(this.progress);

  final double progress;

  static const List<Color> _palette = <Color>[
    Color(0xFFE53935),
    Color(0xFFFFB300),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFF8E24AA),
    Color(0xFFFFFFFF),
    Color(0xFF212121),
    Color(0xFFFFEB3B),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final double cell = size.width / GlassCheckScreen.columns;
    final double offset = progress * cell * GlassCheckScreen.rows * 0.5;
    final Paint paint = Paint();
    final int firstRow = (offset / cell).floor();
    final int visibleRows = (size.height / cell).ceil() + 1;
    for (var r = 0; r < visibleRows; r++) {
      final int row = (firstRow + r) % GlassCheckScreen.rows;
      for (var c = 0; c < GlassCheckScreen.columns; c++) {
        paint.color = _palette[(row * 7 + c * 3 + (row ~/ 5)) % _palette.length];
        canvas.drawRect(Rect.fromLTWH(c * cell, r * cell - (offset % cell), cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => oldDelegate.progress != progress;
}
