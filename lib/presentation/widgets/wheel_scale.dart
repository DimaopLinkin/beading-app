import 'dart:async';
import 'dart:math' as math;

import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Шкала-«колесо» (макет 18): значение под неподвижной меткой по центру, шкала прокручивается пальцем, как у
/// редакторов фото и видео. Шаг защёлкивается с лёгкой отдачей. Своего системного аналога нет.
class WheelScale extends StatefulWidget {
  const WheelScale({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    super.key,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  /// Расстояние между делениями, логических пикселей.
  static const double tick = 12;

  @override
  State<WheelScale> createState() => _WheelScaleState();
}

class _WheelScaleState extends State<WheelScale> {
  late final ScrollController _controller = ScrollController(initialScrollOffset: _offsetOf(widget.value));
  bool _dragging = false;

  int get _count => ((widget.max - widget.min) / widget.step).round();
  int _indexOf(double value) => ((value - widget.min) / widget.step).round().clamp(0, _count);
  double _offsetOf(double value) => _indexOf(value) * WheelScale.tick;

  @override
  void didUpdateWidget(covariant WheelScale oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Значение изменили кнопками − и + или вводом: колесо едет за ним, пока палец не на шкале.
    if (!_dragging && _controller.hasClients && (_controller.offset - _offsetOf(widget.value)).abs() > 0.5) {
      unawaited(
        _controller.animateTo(_offsetOf(widget.value), duration: const Duration(milliseconds: 150), curve: Curves.ease),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification note) {
    if (note is ScrollStartNotification && note.dragDetails != null) {
      _dragging = true;
    } else if (note is ScrollUpdateNotification && _dragging) {
      final int index = (note.metrics.pixels / WheelScale.tick).round().clamp(0, _count);
      final double next = widget.min + index * widget.step;
      if ((next - widget.value).abs() > widget.step / 2) {
        unawaited(HapticFeedback.selectionClick());
        widget.onChanged(next);
      }
    } else if (note is ScrollEndNotification && _dragging) {
      _dragging = false;
      final double target = (note.metrics.pixels / WheelScale.tick).round().clamp(0, _count) * WheelScale.tick;
      if ((note.metrics.pixels - target).abs() > 0.5) {
        unawaited(_controller.animateTo(target, duration: const Duration(milliseconds: 120), curve: Curves.ease));
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = CupertinoTheme.of(context).primaryColor;
    final Color tickColor = CupertinoColors.tertiaryLabel.resolveFrom(context);
    final double tap = context.tokens.minTapTarget;
    return SizedBox(
      height: tap,
      child: LayoutBuilder(
        builder: (context, box) {
          final double side = math.max(0, (box.maxWidth - WheelScale.tick) / 2);
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ListView.builder(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  itemExtent: WheelScale.tick,
                  itemCount: _count + 1,
                  padding: EdgeInsets.symmetric(horizontal: side),
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, index) => Center(
                    child: Container(
                      width: 1.5,
                      height: index % 5 == 0 ? 20 : 12,
                      color: tickColor,
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Container(
                  width: 3,
                  height: 28,
                  decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
