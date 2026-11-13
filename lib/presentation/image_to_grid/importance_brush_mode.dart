import 'dart:math' as math;
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/importance_brush.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_cubit.dart';
import 'package:beading/presentation/image_to_grid/image_wizard_state.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Янтарь подсветки «важного»: не цвет бисера, поэтому читается поверх любой картинки (макет 12).
const Color _amber = Color(0xFFFFA000);

/// Режим «Выделить важное» (T60): предпросмотр целиком, мазок пальцем рисует «важное», внизу панель кисти.
/// Один палец рисует, два масштабируют и двигают картинку.
class ImportanceBrushMode extends StatefulWidget {
  const ImportanceBrushMode({required this.state, super.key});

  final ImageWizardState state;

  @override
  State<ImportanceBrushMode> createState() => _ImportanceBrushModeState();
}

class _ImportanceBrushModeState extends State<ImportanceBrushMode> {
  final TransformationController _controller = TransformationController();
  final ValueNotifier<List<double>?> _live = ValueNotifier<List<double>?>(null);

  /// Кружок кисти под пальцем или курсором в координатах картинки (в пикселях экрана при масштабе 1).
  final ValueNotifier<Offset?> _cursor = ValueNotifier<Offset?>(null);
  final Set<int> _pointers = <int>{};
  int? _drawing;
  List<double> _points = <double>[];

  @override
  void dispose() {
    _controller.dispose();
    _live.dispose();
    _cursor.dispose();
    super.dispose();
  }

  Offset _fraction(Offset local, Size size) {
    final Offset scene = _controller.toScene(local);
    return Offset(scene.dx / size.width, scene.dy / size.height);
  }

  void _down(PointerDownEvent e, Size size) {
    _pointers.add(e.pointer);
    if (_pointers.length > 1) {
      _drawing = null;
      _points = <double>[];
      _live.value = null;
      _cursor.value = null;
      setState(() {});
      return;
    }
    final Offset f = _fraction(e.localPosition, size);
    _cursor.value = Offset(f.dx * size.width, f.dy * size.height);
    _drawing = e.pointer;
    _points = <double>[f.dx, f.dy];
    if (widget.state.brushEraser) {
      context.read<ImageWizardCubit>().eraseBrush(_points);
    } else {
      _live.value = _points;
    }
  }

  /// Мышь над картинкой без нажатия: кружок размера кисти идёт за курсором.
  void _hover(PointerHoverEvent e, Size size) {
    if (_pointers.isNotEmpty || e.kind == PointerDeviceKind.touch) {
      return;
    }
    final Offset f = _fraction(e.localPosition, size);
    _cursor.value = Offset(f.dx * size.width, f.dy * size.height);
  }

  void _move(PointerMoveEvent e, Size size) {
    if (_drawing != e.pointer) {
      return;
    }
    final Offset f = _fraction(e.localPosition, size);
    _cursor.value = Offset(f.dx * size.width, f.dy * size.height);
    if (widget.state.brushEraser) {
      context.read<ImageWizardCubit>().eraseBrush(<double>[f.dx, f.dy]);
      return;
    }
    _points = <double>[..._points, f.dx, f.dy];
    _live.value = _points;
  }

  void _up(PointerEvent e, {required bool commit}) {
    final bool wasPair = _pointers.length > 1;
    _pointers.remove(e.pointer);
    if (wasPair && _pointers.length == 1) {
      setState(() {});
    }
    if (_drawing != e.pointer) {
      return;
    }
    _drawing = null;
    _cursor.value = null;
    if (commit && !widget.state.brushEraser) {
      context.read<ImageWizardCubit>().addBrushStroke(_points);
    }
    _points = <double>[];
    _live.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImageWizardState state = widget.state;
    final AppTokensData tokens = context.tokens;
    final TextStyle caption = TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context));
    final bool pinching = _pointers.length > 1;
    final MediaQueryData media = MediaQuery.of(context);
    // Mac и планшет: панель кисти в боковой колонке слева, справа картинка.
    final bool wide = media.size.width >= 700;
    final Widget panel = _BrushPanel(state: state);
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m, vertical: tokens.spacing.xs),
          child: Text(l10n.imageWizardBrushHint, style: caption, textAlign: TextAlign.center),
        ),
        Expanded(
          child: Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            children: <Widget>[
              if (wide)
                SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        panel,
                        if (!state.hasMasks && state.brush.isEmpty)
                          Padding(
                            padding: EdgeInsets.all(tokens.spacing.m),
                            child: Text(l10n.imageWizardBrushEmpty, style: caption, textAlign: TextAlign.center),
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final int pw = math.max(1, state.preparedWidth);
                    final int ph = math.max(1, state.preparedHeight);
                    final double k = math.min(
                      (box.maxWidth - 2 * tokens.spacing.m) / pw,
                      (box.maxHeight - 2 * tokens.spacing.s) / ph,
                    );
                    final Size size = Size(pw * k, ph * k);
                    final PreparedFrame frame = PreparedFrame(
                      width: pw,
                      height: ph,
                      quarterTurns: state.quarterTurns,
                      crop: state.crop,
                    );
                    return Center(
                      child: Semantics(
                        label: l10n.imageWizardBrushCanvas,
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: ClipRect(
                            child: MouseRegion(
                              cursor: SystemMouseCursors.precise,
                              onExit: (_) {
                                if (_drawing == null) {
                                  _cursor.value = null;
                                }
                              },
                              child: Listener(
                                key: const ValueKey<String>('brush-canvas'),
                                behavior: HitTestBehavior.opaque,
                                onPointerHover: (e) => _hover(e, size),
                                onPointerDown: (e) => _down(e, size),
                                onPointerMove: (e) => _move(e, size),
                                onPointerUp: (e) => _up(e, commit: true),
                                onPointerCancel: (e) => _up(e, commit: false),
                                child: InteractiveViewer(
                                  transformationController: _controller,
                                  constrained: false,
                                  minScale: 1,
                                  maxScale: 6,
                                  panEnabled: pinching,
                                  scaleEnabled: pinching,
                                  child: SizedBox(
                                    width: size.width,
                                    height: size.height,
                                    child: Stack(
                                      children: <Widget>[
                                        Positioned.fill(
                                          child: Image.memory(
                                            state.prepared!,
                                            fit: BoxFit.fill,
                                            gaplessPlayback: true,
                                            excludeFromSemantics: true,
                                            errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: _BrushPainter(
                                              brush: state.brush,
                                              frame: frame,
                                              masks: state.brushShowAuto ? state.masks : null,
                                              live: _live,
                                              cursor: _cursor,
                                              liveRadius: ImageWizardState.brushSizes[state.brushSize],
                                              liveVisible: !state.brushEraser,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (!wide) ...<Widget>[
                if (!state.hasMasks && state.brush.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l, vertical: tokens.spacing.xs),
                    child: Text(l10n.imageWizardBrushEmpty, style: caption, textAlign: TextAlign.center),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: media.size.height * 0.45),
                  child: SingleChildScrollView(
                    child: SizedBox(width: double.infinity, child: panel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BrushPanel extends StatelessWidget {
  const _BrushPanel({required this.state});

  final ImageWizardState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ImageWizardCubit cubit = context.read<ImageWizardCubit>();
    final AppTokensData tokens = context.tokens;
    final Color accent = tokens.accent.resolveFrom(context);
    final List<String> sizeNames = <String>[
      l10n.imageWizardBrushSmall,
      l10n.imageWizardBrushMedium,
      l10n.imageWizardBrushLarge,
    ];
    return Container(
      key: const ValueKey<String>('brush-panel'),
      padding: EdgeInsets.fromLTRB(tokens.spacing.m, tokens.spacing.s, tokens.spacing.m, tokens.spacing.s),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        border: Border(top: BorderSide(color: CupertinoColors.separator.resolveFrom(context), width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (state.hasMasks)
            MergeSemantics(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(l10n.imageWizardBrushShowAuto, style: const TextStyle(fontSize: 15)),
                  ),
                  CupertinoSwitch(
                    key: const ValueKey<String>('brush-show-auto'),
                    value: state.brushShowAuto,
                    onChanged: (v) => cubit.setBrushShowAuto(value: v),
                  ),
                ],
              ),
            ),
          SizedBox(height: tokens.spacing.xs),
          CupertinoSlidingSegmentedControl<bool>(
            key: const ValueKey<String>('brush-tool'),
            groupValue: state.brushEraser,
            onValueChanged: (eraser) => cubit.setBrushEraser(eraser: eraser ?? false),
            children: <bool, Widget>{
              false: _Segment(
                key: const ValueKey<String>('brush-draw'),
                icon: CupertinoIcons.paintbrush,
                label: l10n.imageWizardBrushBrush,
                color: !state.brushEraser ? accent : null,
              ),
              true: _Segment(
                key: const ValueKey<String>('brush-eraser'),
                icon: CupertinoIcons.delete_left,
                label: l10n.imageWizardBrushEraser,
                color: state.brushEraser ? accent : null,
              ),
            },
          ),
          SizedBox(height: tokens.spacing.xs),
          CupertinoSlidingSegmentedControl<int>(
            key: const ValueKey<String>('brush-size'),
            groupValue: state.brushSize,
            onValueChanged: (i) => cubit.setBrushSize(i ?? state.brushSize),
            children: <int, Widget>{
              for (final (int i, String name) in sizeNames.indexed)
                i: _Segment(
                  key: ValueKey<String>('brush-size-$i'),
                  iconWidget: Container(
                    width: 8 + ImageWizardState.brushSizes[i] * 100,
                    height: 8 + ImageWizardState.brushSizes[i] * 100,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: _amber),
                  ),
                  label: name,
                ),
            },
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              CupertinoButton(
                key: const ValueKey<String>('brush-clear'),
                padding: EdgeInsets.zero,
                minimumSize: Size.square(tokens.minTapTarget),
                onPressed: state.brush.isEmpty ? null : () => _confirmClear(context, cubit),
                child: Text(l10n.imageWizardBrushClear, style: const TextStyle(fontSize: 15)),
              ),
              CupertinoButton(
                key: const ValueKey<String>('brush-undo'),
                padding: EdgeInsets.zero,
                minimumSize: Size.square(tokens.minTapTarget),
                onPressed: state.canUndoBrush ? cubit.undoBrush : null,
                child: Text(l10n.imageWizardBrushUndo, style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, ImageWizardCubit cubit) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        message: Text(l10n.imageWizardBrushClearMessage),
        actions: <Widget>[
          CupertinoActionSheetAction(
            key: const ValueKey<String>('brush-clear-confirm'),
            isDestructiveAction: true,
            onPressed: () {
              cubit.clearBrush();
              Navigator.of(sheet).pop();
            },
            child: Text(l10n.imageWizardBrushClear),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheet).pop(),
          child: Text(l10n.imageWizardCancel),
        ),
      ),
    );
  }
}

/// Содержимое сегмента панели кисти: значок и подпись в одну строку (в макете 12 это `sc3`).
class _Segment extends StatelessWidget {
  const _Segment({required this.label, this.icon, this.iconWidget, this.color, super.key});

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color tone = color ?? CupertinoColors.label.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 22,
            height: 22,
            child: Center(child: iconWidget ?? Icon(icon, size: 20, color: tone)),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

/// Рисует поверх картинки найденное генератором (по желанию), мазки пользователя и мазок под пальцем.
class _BrushPainter extends CustomPainter {
  _BrushPainter({
    required this.brush,
    required this.frame,
    required this.masks,
    required this.live,
    required this.cursor,
    required this.liveRadius,
    required this.liveVisible,
  }) : super(repaint: Listenable.merge(<Listenable>[live, cursor]));

  final ImportanceBrush brush;
  final PreparedFrame frame;
  final ImageMaskSet? masks;
  final ValueNotifier<List<double>?> live;
  final ValueNotifier<Offset?> cursor;
  final double liveRadius;
  final bool liveVisible;

  @override
  void paint(Canvas canvas, Size size) {
    final double perPx = size.width / frame.width;
    final double short = frame.shortSide * perPx;
    final ImageMaskSet? found = masks;
    if (found != null) {
      _paintFound(canvas, size, found);
    }
    for (final BrushStroke s in brush.strokes) {
      final List<Offset> pts = <Offset>[
        for (int i = 0; i + 1 < s.points.length; i += 2) _toCanvas(s.points[i], s.points[i + 1], size),
      ];
      _paintStroke(canvas, pts, s.radius * short * 2);
    }
    final List<double>? now = live.value;
    if (liveVisible && now != null && now.length >= 2) {
      _paintStroke(canvas, <Offset>[
        for (int i = 0; i + 1 < now.length; i += 2) Offset(now[i] * size.width, now[i + 1] * size.height),
      ], liveRadius * short * 2);
    }
    final Offset? at = cursor.value;
    if (at != null) {
      // Кружок размера кисти: тёмный и белый контур, чтобы читался на любой картинке.
      canvas
        ..drawCircle(
          at,
          liveRadius * short,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xCC000000),
        )
        ..drawCircle(
          at,
          liveRadius * short,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFFFFFFFF),
        );
    }
  }

  Offset _toCanvas(double x, double y, Size size) {
    final (double, double) p = frame.toPrepared(x, y);
    return Offset(p.$1 * size.width, p.$2 * size.height);
  }

  /// Двойной контур (тёмный и белый) и полупрозрачная янтарная заливка: подсветка не путается с цветами бисера.
  void _paintStroke(Canvas canvas, List<Offset> pts, double width) {
    if (pts.isEmpty) {
      return;
    }
    final Path path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 1) {
      path.lineTo(pts.first.dx + 0.01, pts.first.dy);
    }
    for (final Offset p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    Paint line(Color color, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w
      ..color = color;
    canvas
      ..drawPath(path, line(const Color(0xCC000000), width + 4))
      ..drawPath(path, line(const Color(0xFFFFFFFF), width + 2))
      ..drawPath(path, line(_amber.withValues(alpha: 0.45), width));
    // Косая штриховка под мазком: подсветка отличается от оранжевых бусин и без цвета (слой с маской по мазку).
    final Rect bounds = path.getBounds().inflate(width / 2 + 2);
    canvas.saveLayer(bounds, Paint());
    final Paint hatch = Paint()
      ..strokeWidth = 1.5
      ..color = const Color(0xCC7A4A00);
    for (double x = bounds.left - bounds.height; x < bounds.right; x += 6) {
      canvas.drawLine(Offset(x, bounds.bottom), Offset(x + bounds.height, bounds.top), hatch);
    }
    canvas
      ..drawPath(path, line(const Color(0xFFFFFFFF), width)..blendMode = BlendMode.dstIn)
      ..restore();
  }

  /// Найденное генератором: объект сеткой ячеек и рамки лиц, пунктиром не рисуем, а тоньше и бледнее ваших мазков.
  void _paintFound(Canvas canvas, Size size, ImageMaskSet found) {
    final Paint fill = Paint()..color = _amber.withValues(alpha: 0.25);
    final Uint8List? object = found.subjectOrPerson;
    if (object != null) {
      const int steps = 48;
      final double cw = size.width / steps;
      final double ch = size.height / steps;
      for (int gy = 0; gy < steps; gy++) {
        for (int gx = 0; gx < steps; gx++) {
          final int x = ((gx + 0.5) / steps * found.width).floor().clamp(0, found.width - 1);
          final int y = ((gy + 0.5) / steps * found.height).floor().clamp(0, found.height - 1);
          if (object[y * found.width + x] != 0) {
            canvas.drawRect(Rect.fromLTWH(gx * cw, gy * ch, cw + 0.5, ch + 0.5), fill);
          }
        }
      }
    }
    final Paint edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _amber;
    for (final DetectedFace face in found.faces) {
      final NormalizedRect b = face.bounds;
      final Rect r = Rect.fromLTRB(
        b.left * size.width,
        b.top * size.height,
        b.right * size.width,
        b.bottom * size.height,
      );
      canvas
        ..drawRect(r, fill)
        ..drawRect(r, edge);
    }
  }

  @override
  bool shouldRepaint(_BrushPainter old) =>
      old.brush != brush ||
      old.frame != frame ||
      old.masks != masks ||
      old.liveRadius != liveRadius ||
      old.liveVisible != liveVisible;
}
