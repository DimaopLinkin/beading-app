import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
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
  static const double _grab = 28;

  late CropRect _crop = widget.initial;
  late final Future<ui.Image> _image = _decode();
  String? _edge;

  Future<ui.Image> _decode() async {
    final ui.Codec codec = await ui.instantiateImageCodec(widget.bytes);
    final ui.Image image = (await codec.getNextFrame()).image;
    codec.dispose();
    return image;
  }

  void _start(Offset position, Size size) {
    final Map<String, double> distances = <String, double>{
      'left': (position.dx - _crop.left * size.width).abs(),
      'right': (position.dx - _crop.right * size.width).abs(),
      'top': (position.dy - _crop.top * size.height).abs(),
      'bottom': (position.dy - _crop.bottom * size.height).abs(),
    };
    final MapEntry<String, double> nearest = distances.entries.reduce((a, b) => a.value <= b.value ? a : b);
    _edge = nearest.value <= _grab ? nearest.key : null;
  }

  void _update(Offset position, Size size) {
    final String? edge = _edge;
    if (edge == null) {
      return;
    }
    final double x = (position.dx / size.width).clamp(0, 1);
    final double y = (position.dy / size.height).clamp(0, 1);
    setState(() {
      _crop = switch (edge) {
        'left' => CropRect(
          left: x.clamp(0, _crop.right - _minSide),
          top: _crop.top,
          right: _crop.right,
          bottom: _crop.bottom,
        ),
        'right' => CropRect(
          left: _crop.left,
          top: _crop.top,
          right: x.clamp(_crop.left + _minSide, 1),
          bottom: _crop.bottom,
        ),
        'top' => CropRect(
          left: _crop.left,
          top: y.clamp(0, _crop.bottom - _minSide),
          right: _crop.right,
          bottom: _crop.bottom,
        ),
        _ => CropRect(left: _crop.left, top: _crop.top, right: _crop.right, bottom: y.clamp(_crop.top + _minSide, 1)),
      };
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
    final AppTokensData tokens = context.tokens;
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
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.l),
                child: FutureBuilder<ui.Image>(
                  future: _image,
                  builder: (context, snapshot) {
                    final ui.Image? image = snapshot.data;
                    if (image == null) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    final bool swap = widget.quarterTurns.isOdd;
                    final double ratio = swap ? image.height / image.width : image.width / image.height;
                    return Center(
                      child: AspectRatio(
                        aspectRatio: ratio,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final Size size = constraints.biggest;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (d) => _start(d.localPosition, size),
                              onPanUpdate: (d) => _update(d.localPosition, size),
                              child: Stack(
                                fit: StackFit.expand,
                                children: <Widget>[
                                  RotatedBox(
                                    quarterTurns: widget.quarterTurns,
                                    child: Image.memory(widget.bytes, fit: BoxFit.fill, gaplessPlayback: true),
                                  ),
                                  CustomPaint(
                                    painter: _CropPainter(_crop, CupertinoColors.activeBlue.resolveFrom(context)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
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
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) => oldDelegate.crop != crop || oldDelegate.accent != accent;
}
