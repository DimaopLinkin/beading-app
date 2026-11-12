import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

/// Экран обрезки: картинка с рамкой, края которой тянутся пальцем. Возвращает [CropRect] или `null` при отмене.
Future<CropRect?> showCropEditor(
  BuildContext context, {
  required Uint8List bytes,
  required int quarterTurns,
  required CropRect initial,
}) => Navigator.of(context).push<CropRect>(
  CupertinoPageRoute<CropRect>(
    fullscreenDialog: true,
    builder: (_) => CropEditor(bytes: bytes, quarterTurns: quarterTurns, initial: initial),
  ),
);

class CropEditor extends StatefulWidget {
  const CropEditor({required this.bytes, required this.quarterTurns, required this.initial, super.key});

  final Uint8List bytes;
  final int quarterTurns;
  final CropRect initial;

  @override
  State<CropEditor> createState() => _CropEditorState();
}

class _CropEditorState extends State<CropEditor> {
  static const double _minSide = 0.05;

  /// Радиус захвата вокруг края рамки: зона касания 2 × 24 = 48 pt, не меньше 44 pt по HIG. Она выходит за пределы
  /// картинки, поэтому рамку, прижатую к краю, можно взять и снаружи.
  static const double _grab = 24;

  /// Поле вокруг картинки, в котором ещё ловятся касания и рисуются ручки.
  static const double _margin = 28;

  late CropRect _crop = widget.initial;
  late final Future<ui.Image> _image = _decode();
  String? _horizontal;
  String? _vertical;

  Future<ui.Image> _decode() async {
    final ui.Codec codec = await ui.instantiateImageCodec(widget.bytes);
    final ui.Image image = (await codec.getNextFrame()).image;
    codec.dispose();
    return image;
  }

  /// Какие края берёт касание в [position] (в пикселях картинки): угол даёт сразу два края.
  void _start(Offset position, Size size) {
    final double left = _crop.left * size.width;
    final double right = _crop.right * size.width;
    final double top = _crop.top * size.height;
    final double bottom = _crop.bottom * size.height;
    final bool withinX = position.dx >= left - _grab && position.dx <= right + _grab;
    final bool withinY = position.dy >= top - _grab && position.dy <= bottom + _grab;
    final double dLeft = (position.dx - left).abs();
    final double dRight = (position.dx - right).abs();
    final double dTop = (position.dy - top).abs();
    final double dBottom = (position.dy - bottom).abs();
    final bool leftCloser = dLeft == dRight ? position.dx < (left + right) / 2 : dLeft < dRight;
    final bool topCloser = dTop == dBottom ? position.dy < (top + bottom) / 2 : dTop < dBottom;
    final double nearX = leftCloser ? dLeft : dRight;
    final double nearY = topCloser ? dTop : dBottom;
    _horizontal = withinY && nearX <= _grab ? (leftCloser ? 'left' : 'right') : null;
    _vertical = withinX && nearY <= _grab ? (topCloser ? 'top' : 'bottom') : null;
  }

  void _update(Offset delta, Size size) {
    final String? horizontal = _horizontal;
    final String? vertical = _vertical;
    if (horizontal == null && vertical == null) {
      return;
    }
    final double dx = delta.dx / size.width;
    final double dy = delta.dy / size.height;
    setState(() {
      double left = _crop.left;
      double right = _crop.right;
      double top = _crop.top;
      double bottom = _crop.bottom;
      if (horizontal == 'left') {
        left = (left + dx).clamp(0, right - _minSide);
      } else if (horizontal == 'right') {
        right = (right + dx).clamp(left + _minSide, 1);
      }
      if (vertical == 'top') {
        top = (top + dy).clamp(0, bottom - _minSide);
      } else if (vertical == 'bottom') {
        bottom = (bottom + dy).clamp(top + _minSide, 1);
      }
      _crop = CropRect(left: left, top: top, right: right, bottom: bottom);
    });
  }

  @override
  void dispose() {
    unawaited(_image.then((image) => image.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.importCropTitle),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.importBookCancel),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(_crop),
          child: Text(l10n.importCropDone),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: FutureBuilder<ui.Image>(
                future: _image,
                builder: (context, snapshot) {
                  final ui.Image? image = snapshot.data;
                  if (image == null) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  final bool swap = widget.quarterTurns.isOdd;
                  final double ratio = swap ? image.height / image.width : image.width / image.height;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final Size available = Size(
                        math.max(1, constraints.maxWidth - 2 * _margin),
                        math.max(1, constraints.maxHeight - 2 * _margin),
                      );
                      final Size size = available.width / available.height > ratio
                          ? Size(available.height * ratio, available.height)
                          : Size(available.width, available.width / ratio);
                      final Color accent = CupertinoColors.activeBlue.resolveFrom(context);
                      // Жест ловится на всей области, а не только на картинке: рамку у края берут и снаружи.
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => _start(d.localPosition - _origin(constraints.biggest, size), size),
                        onPanUpdate: (d) => _update(d.delta, size),
                        child: Center(
                          child: SizedBox(
                            width: size.width,
                            height: size.height,
                            child: Stack(
                              clipBehavior: Clip.none,
                              fit: StackFit.expand,
                              children: <Widget>[
                                RotatedBox(
                                  quarterTurns: widget.quarterTurns,
                                  child: Image.memory(widget.bytes, fit: BoxFit.fill, gaplessPlayback: true),
                                ),
                                CustomPaint(painter: _CropPainter(_crop, accent)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            CupertinoButton(
              onPressed: () => setState(() => _crop = CropRect.full),
              child: Text(l10n.importCropReset),
            ),
          ],
        ),
      ),
    );
  }

  Offset _origin(Size area, Size image) => Offset((area.width - image.width) / 2, (area.height - image.height) / 2);
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.crop, this.accent);

  final CropRect crop;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    final Rect inner = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    canvas
      ..drawPath(
        Path.combine(PathOperation.difference, Path()..addRect(all), Path()..addRect(inner)),
        Paint()..color = const Color(0x99000000),
      )
      ..drawRect(
        inner,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    // Явные «хваталки»: уголки и середины сторон, они рисуются и за пределами картинки, если рамка у края.
    final Paint handle = Paint()..color = accent;
    final Paint rim = Paint()..color = const Color(0xFFFFFFFF);
    for (final Offset point in <Offset>[
      inner.topLeft,
      inner.topRight,
      inner.bottomLeft,
      inner.bottomRight,
      inner.topCenter,
      inner.bottomCenter,
      inner.centerLeft,
      inner.centerRight,
    ]) {
      canvas
        ..drawCircle(point, 8, rim)
        ..drawCircle(point, 6, handle);
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) => oldDelegate.crop != crop || oldDelegate.accent != accent;
}
