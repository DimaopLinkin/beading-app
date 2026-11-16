import 'dart:math' as math;

import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/stats/chart_buckets.dart';
import 'package:beading/presentation/stats/duration_format.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Столбчатый график времени: тонкая сетка, ось справа, нажатие на столбик с работой показывает выноску.
/// Цвет — акцент интерфейса, не цвета бусин. [byMonths] — подписи месяцев (первая буква), иначе дни.
class TimeBarChart extends StatefulWidget {
  const TimeBarChart({required this.bars, required this.byMonths, this.weekdayLabels = false, super.key});

  final List<ChartBar> bars;
  final bool byMonths;

  /// Подписывать каждый столбик днём недели (у недели); иначе — числом через несколько столбиков.
  final bool weekdayLabels;

  static const double height = 150;

  @override
  State<TimeBarChart> createState() => _TimeBarChartState();
}

class _TimeBarChartState extends State<TimeBarChart> {
  int? _selected;

  @override
  void didUpdateWidget(TimeBarChart old) {
    super.didUpdateWidget(old);
    if (old.bars != widget.bars) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final Color accent = CupertinoTheme.of(context).primaryColor;
    final Color grid = CupertinoColors.separator.resolveFrom(context);
    final Color label = CupertinoColors.secondaryLabel.resolveFrom(context);
    final String locale = Localizations.localeOf(context).toString();
    final TextStyle labelStyle = TextStyle(fontSize: 13, color: label);
    final Duration peak = widget.bars.fold(Duration.zero, (a, b) => b.time > a ? b.time : a);
    final double step = _axisStep(peak);
    final double top = math.max(step, (peak.inMinutes / 60 / step).ceil() * step);
    final int? selected = _selected;

    String axis(double hours) => hours == 0 ? '0' : formatWorkTime(l10n, Duration(minutes: (hours * 60).round()));

    String barLabel(int i) {
      final DateTime d = widget.bars[i].start;
      if (widget.byMonths) {
        return DateFormat('MMMMM', locale).format(d).toUpperCase();
      }
      if (widget.weekdayLabels) {
        return DateFormat.E(locale).format(d);
      }
      return (i == 0 || (i + 1) % 7 == 1 || i == widget.bars.length - 1) && d.day != 31 ? '${d.day}' : '';
    }

    final String values = <String>[
      for (final ChartBar bar in widget.bars)
        if (bar.time.inMinutes > 0) l10n.statsChartBarValue(formatWorkTime(l10n, bar.time), bar.start),
    ].join('; ');
    return Semantics(
      container: true,
      label: widget.byMonths ? l10n.statsChartMonths : l10n.statsChartDays,
      value: values,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final int n = widget.bars.length;
              if (n == 0) {
                return;
              }
              const double axisWidth = 44;
              final double slot = (width - axisWidth) / n;
              final int i = (details.localPosition.dx / slot).floor();
              setState(() => _selected = i >= 0 && i < n && widget.bars[i].time.inMinutes > 0 ? i : null);
            },
            child: SizedBox(
              height: TimeBarChart.height + 26,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ChartPainter(
                        bars: widget.bars,
                        top: top,
                        step: step,
                        accent: accent,
                        dim: accent.withValues(alpha: 0.35),
                        grid: grid,
                        labelStyle: labelStyle,
                        selected: selected,
                        axis: axis,
                        barLabel: barLabel,
                        radius: tokens.radius.s / 2,
                      ),
                    ),
                  ),
                  if (selected != null)
                    Positioned(
                      left: _tooltipLeft(selected, width),
                      top: 0,
                      child: _Tooltip(
                        text: l10n.statsChartBarValue(
                          formatWorkTime(l10n, widget.bars[selected].time),
                          widget.bars[selected].start,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  double _tooltipLeft(int i, double width) {
    const double axisWidth = 44;
    final double slot = (width - axisWidth) / widget.bars.length;
    return (slot * (i + 0.5) - 60).clamp(0, math.max(0, width - axisWidth - 120));
  }

  /// Шаг оси в часах: 1/2 ч, 1, 2, 5, 10, 20 … так, чтобы линий было 2–4.
  static double _axisStep(Duration peak) {
    final double hours = peak.inMinutes / 60;
    for (final double s in <double>[0.5, 1, 2, 5, 10, 20, 50, 100, 200, 500]) {
      if (hours / s <= 4) {
        return s;
      }
    }
    return 1000;
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
    ),
    child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
  );
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.bars,
    required this.top,
    required this.step,
    required this.accent,
    required this.dim,
    required this.grid,
    required this.labelStyle,
    required this.selected,
    required this.axis,
    required this.barLabel,
    required this.radius,
  });

  final List<ChartBar> bars;
  final double top;
  final double step;
  final Color accent;
  final Color dim;
  final Color grid;
  final TextStyle labelStyle;
  final int? selected;
  final String Function(double hours) axis;
  final String Function(int index) barLabel;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const double axisWidth = 44;
    final double plotWidth = size.width - axisWidth;
    const double plotHeight = TimeBarChart.height - 20;
    const double plotTop = 20;
    final Paint line = Paint()
      ..color = grid
      ..strokeWidth = 0.5;
    for (double v = 0; v <= top + 1e-9; v += step) {
      final double y = plotTop + plotHeight * (1 - v / top);
      canvas.drawLine(Offset(0, y), Offset(plotWidth, y), line);
      _text(canvas, axis(v), Offset(plotWidth + 6, y - 8), labelStyle);
    }
    if (bars.isEmpty) {
      return;
    }
    final double slot = plotWidth / bars.length;
    final double barWidth = math.max(2, slot * 0.62);
    for (int i = 0; i < bars.length; i++) {
      final double hours = bars[i].time.inMinutes / 60;
      final double h = plotHeight * (hours / top);
      final double x = slot * i + (slot - barWidth) / 2;
      final bool faded = selected != null && selected != i;
      if (h > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, plotTop + plotHeight - h, barWidth, h),
            topLeft: Radius.circular(radius),
            topRight: Radius.circular(radius),
          ),
          Paint()..color = faded ? dim : accent,
        );
      }
      final String text = barLabel(i);
      if (text.isNotEmpty && (slot >= 16 || text.length <= 2)) {
        _text(canvas, text, Offset(slot * i + slot / 2, plotTop + plotHeight + 4), labelStyle, center: true);
      }
    }
    // Нижняя линия графика поверх столбцов.
    canvas.drawLine(const Offset(0, plotTop + plotHeight), Offset(plotWidth, plotTop + plotHeight), line);
  }

  void _text(Canvas canvas, String text, Offset at, TextStyle style, {bool center = false}) {
    final TextPainter p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, center ? Offset(at.dx - p.width / 2, at.dy) : at);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.bars != bars || old.selected != selected || old.accent != accent || old.grid != grid;
}
