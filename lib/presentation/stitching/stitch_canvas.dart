import 'dart:async';
import 'dart:math' as math;

import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/stitch_counters.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/stitching/stitch_state.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

/// Полотно вышивания: схема с зумом и сдвигом. Два пальца всегда двигают и масштабируют; один палец делает то, что
/// выбрано: [StitchTool.tap] — касание отмечает клетку, палец тянется — двигает схему; [StitchTool.stroke] — мазок
/// отмечает клетки под пальцем; [StitchTool.area] — рамка области. Долгое касание паркует клетку.
class StitchCanvas extends StatefulWidget {
  const StitchCanvas({
    required this.pattern,
    required this.state,
    required this.options,
    required this.onTap,
    required this.onLongPress,
    required this.onStrokeStart,
    required this.onStrokeCell,
    required this.onStrokeEnd,
    required this.onArea,
    required this.onAreaEnd,
    this.layers,
    this.controller,
    super.key,
  });

  final GridPattern pattern;
  final StitchState state;
  final GridViewOptions options;
  final StitchLayers? layers;
  final ValueChanged<CellPosition> onTap;
  final ValueChanged<CellPosition> onLongPress;
  final VoidCallback onStrokeStart;
  final ValueChanged<CellPosition> onStrokeCell;
  final VoidCallback onStrokeEnd;
  final void Function(CellPosition anchor, CellPosition current) onArea;
  final VoidCallback onAreaEnd;

  /// Зум и сдвиг снаружи (тесты, «доехать до парковки»); иначе полотно ведёт своё преобразование.
  final TransformationController? controller;

  @override
  State<StitchCanvas> createState() => _StitchCanvasState();
}

class _StitchCanvasState extends State<StitchCanvas> {
  static const double _minScale = 0.25;
  static const double _maxScale = 12;
  static const double _tapSlop = 8;
  static const Duration _longPress = Duration(milliseconds: 500);

  /// Клетка уже этого экранного размера: знак читается и в неё можно попасть касанием.
  static const double _readableCell = 14;

  TransformationController? _own;
  final Map<int, Offset> _pointers = <int, Offset>{};
  late GridScene _scene = _buildScene();
  bool _fitted = false;

  int? _primary;
  Offset? _downAt;
  bool _moved = false;
  bool _multiTouch = false;
  bool _stroking = false;
  CellPosition? _anchor;
  CellPosition? _pendingCell;
  Timer? _longTimer;
  bool _longFired = false;
  final ValueNotifier<bool> _small = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _hint = ValueNotifier<bool>(false);
  Timer? _hintTimer;

  TransformationController get _controller => widget.controller ?? (_own ??= TransformationController());

  GridScene _buildScene() => GridScene(
    geometry: widget.pattern.geometry,
    metrics: widget.pattern.metrics,
    columns: widget.pattern.grid.width,
    rows: widget.pattern.grid.height,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateSmall);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateSmall());
  }

  void _updateSmall() {
    final double cell = _scene.cellRect(const CellPosition(0, 0)).width * _controller.value.storage[0];
    _small.value = cell < _readableCell;
  }

  void _showHint() {
    _hintTimer?.cancel();
    _hint.value = true;
    _hintTimer = Timer(const Duration(seconds: 2), () => _hint.value = false);
  }

  @override
  void didUpdateWidget(StitchCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final GridPattern a = oldWidget.pattern;
    final GridPattern b = widget.pattern;
    if (a.geometry != b.geometry ||
        a.metrics != b.metrics ||
        a.grid.width != b.grid.width ||
        a.grid.height != b.grid.height) {
      _scene = _buildScene();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateSmall);
    _longTimer?.cancel();
    _hintTimer?.cancel();
    _small.dispose();
    _hint.dispose();
    _own?.dispose();
    super.dispose();
  }

  void _fit(Size viewport) {
    if (_fitted) {
      return;
    }
    _fitted = true;
    final double scale = math.min(3, viewport.width / _scene.size.width);
    final double dx = math.max(0, (viewport.width - _scene.size.width * scale) / 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _controller.value = Matrix4.identity()
        ..translateByDouble(dx, 0, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
      _updateSmall();
    });
  }

  CellPosition? _cellAt(Offset local) {
    final Matrix4 inverse = Matrix4.tryInvert(_controller.value) ?? Matrix4.identity();
    return _scene.cellAt(MatrixUtils.transformPoint(inverse, local));
  }

  StitchTool get _tool => widget.state.tool;

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length > 1) {
      _enterGestureMode();
      return;
    }
    _primary = e.pointer;
    _downAt = e.localPosition;
    _longFired = false;
    _longTimer?.cancel();
    _longTimer = Timer(_longPress, _fireLongPress);
    _moved = false;
    _multiTouch = false;
    _pendingCell = _cellAt(e.localPosition);
    _anchor = _tool == StitchTool.area ? _pendingCell : null;
  }

  /// Палец лежит на месте дольше порога: клетка паркуется, отпускание потом ничего не отмечает.
  void _fireLongPress() {
    final CellPosition? cell = _pendingCell;
    if (_moved || _multiTouch || cell == null || _primary == null) {
      return;
    }
    _longFired = true;
    widget.onLongPress(cell);
  }

  void _enterGestureMode() {
    _longTimer?.cancel();
    _multiTouch = true;
    _pendingCell = null;
    _anchor = null;
    _endStroke();
    widget.onAreaEnd();
  }

  void _beginStroke() {
    widget.onStrokeStart();
    _stroking = true;
    final CellPosition? first = _pendingCell;
    _pendingCell = null;
    if (first != null) {
      widget.onStrokeCell(first);
    }
  }

  void _endStroke() {
    if (_stroking) {
      _stroking = false;
      widget.onStrokeEnd();
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) {
      return;
    }
    if (_multiTouch && _pointers.length >= 2) {
      _pinch(e);
      return;
    }
    final Offset before = _pointers[e.pointer]!;
    _pointers[e.pointer] = e.localPosition;
    if (e.pointer != _primary || _multiTouch) {
      return;
    }
    if (!_moved && (e.localPosition - _downAt!).distance > _tapSlop) {
      _moved = true;
      _longTimer?.cancel();
    }
    if (!_moved) {
      return;
    }
    switch (_tool) {
      case StitchTool.tap:
        _transform(e.localPosition, 1, e.localPosition - before);
      case StitchTool.stroke:
        if (!_stroking) {
          _beginStroke();
        }
        final CellPosition? cell = _cellAt(e.localPosition);
        if (cell != null) {
          widget.onStrokeCell(cell);
        }
      case StitchTool.area:
        final CellPosition? cell = _cellAt(e.localPosition);
        if (cell != null && _anchor != null) {
          widget.onArea(_anchor!, cell);
        }
    }
  }

  void _pinch(PointerMoveEvent e) {
    final Offset oldCenter = _center();
    final double oldSpread = _spread();
    _pointers[e.pointer] = e.localPosition;
    final Offset newCenter = _center();
    final double newSpread = _spread();
    final double factor = oldSpread < 1 ? 1 : newSpread / oldSpread;
    _transform(newCenter, factor, newCenter - oldCenter);
  }

  Offset _center() {
    Offset sum = Offset.zero;
    for (final Offset p in _pointers.values) {
      sum += p;
    }
    return sum / _pointers.length.toDouble();
  }

  double _spread() {
    final List<Offset> points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  void _transform(Offset focal, double factor, Offset pan) {
    final Matrix4 current = _controller.value;
    final double scale = current.getMaxScaleOnAxis();
    final double clamped = (scale * factor).clamp(_minScale, _maxScale);
    final double k = clamped / scale;
    _controller.value = Matrix4.identity()
      ..translateByDouble(pan.dx, pan.dy, 0, 1)
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(k, k, 1, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
      ..multiply(current);
  }

  void _up(PointerUpEvent e) {
    final bool wasPrimary = e.pointer == _primary;
    _pointers.remove(e.pointer);
    if (!wasPrimary) {
      return;
    }
    _primary = null;
    _longTimer?.cancel();
    final CellPosition? cell = _pendingCell;
    _pendingCell = null;
    if (!_multiTouch && !_moved && !_longFired) {
      if (cell != null) {
        if (_tool == StitchTool.stroke) {
          // Касание без движения в режиме мазка — одна клетка.
          widget.onStrokeStart();
          widget.onStrokeCell(cell);
          widget.onStrokeEnd();
        } else if (_small.value) {
          _showHint();
        } else {
          widget.onTap(cell);
        }
      }
    }
    _endStroke();
    if (_tool == StitchTool.area) {
      widget.onAreaEnd();
    }
    _anchor = null;
  }

  void _cancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (e.pointer == _primary) {
      _longTimer?.cancel();
      _primary = null;
      _endStroke();
      widget.onAreaEnd();
    }
  }

  void _signal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      _transform(e.localPosition, 1, -e.scrollDelta);
    } else if (e is PointerScaleEvent) {
      _transform(e.localPosition, e.scale, Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _fit(Size(constraints.maxWidth, constraints.maxHeight));
      final Color accent = context.tokens.accent.resolveFrom(context);
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _cancel,
        onPointerSignal: _signal,
        onPointerPanZoomUpdate: (e) => _transform(e.localPosition, e.scale == 1 ? 1 : e.scale, e.panDelta),
        child: ClipRect(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _small,
                  builder: (context, small, _) => GridPatternView(
                    grid: widget.pattern.grid,
                    palette: widget.pattern.palette,
                    geometry: widget.pattern.geometry,
                    metrics: widget.pattern.metrics,
                    layers: widget.layers,
                    controller: _controller,
                    gesturesEnabled: false,
                    maxScale: _maxScale,
                    options: small ? widget.options.withoutSymbols() : widget.options,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: IgnorePointer(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _hint,
                    builder: (context, shown, _) => AnimatedOpacity(
                      opacity: shown ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Center(
                        child: DecoratedBox(
                          key: const ValueKey<String>('stitch-zoom-hint'),
                          decoration: BoxDecoration(
                            color: CupertinoColors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Text(
                              AppLocalizations.of(context).stitchZoomHint,
                              style: const TextStyle(color: CupertinoColors.white, fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.state.showBlocks || widget.state.areaPreview != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => CustomPaint(
                        key: const ValueKey<String>('stitch-overlay'),
                        painter: _StitchOverlayPainter(
                          scene: _scene,
                          matrix: _controller.value,
                          blocks: widget.state.showBlocks ? widget.state.blocks : const <BlockCount>[],
                          area: widget.state.areaPreview,
                          color: accent,
                          textColor: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Поверх схемы: закрытые блоки 10×10 тонируются, у начатых блоков — процент (когда блок крупный на экране), рамка
/// области.
class _StitchOverlayPainter extends CustomPainter {
  const _StitchOverlayPainter({
    required this.scene,
    required this.matrix,
    required this.blocks,
    required this.area,
    required this.color,
    required this.textColor,
  });

  final GridScene scene;
  final Matrix4 matrix;
  final List<BlockCount> blocks;
  final CellRect? area;
  final Color color;
  final Color textColor;

  Rect _blockRect(BlockCount b) {
    const int side = StitchBlocks.side;
    final CellPosition first = CellPosition(b.blockColumn * side, b.blockRow * side);
    final CellPosition last = CellPosition(
      math.min((b.blockColumn + 1) * side, scene.columns) - 1,
      math.min((b.blockRow + 1) * side, scene.rows) - 1,
    );
    return scene.cellRect(first).expandToInclude(scene.cellRect(last));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint done = Paint()..color = const Color(0xFF34C759).withValues(alpha: 0.18);
    final Paint edge = Paint()
      ..color = const Color(0xFF34C759).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final BlockCount b in blocks) {
      final Rect r = MatrixUtils.transformRect(matrix, _blockRect(b));
      if (!r.overlaps(Offset.zero & size)) {
        continue;
      }
      if (b.isComplete) {
        canvas
          ..drawRect(r, done)
          ..drawRect(r, edge);
      } else if (b.done > 0 && r.shortestSide >= 56) {
        final TextPainter text = TextPainter(
          text: TextSpan(
            text: '${(b.fraction * 100).floor()}%',
            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, r.center - Offset(text.width / 2, text.height / 2));
      }
    }
    final CellRect? a = area;
    if (a != null) {
      final Rect onScreen = MatrixUtils.transformRect(
        matrix,
        scene.cellRect(CellPosition(a.left, a.top)).expandToInclude(scene.cellRect(CellPosition(a.right, a.bottom))),
      );
      canvas
        ..drawRect(onScreen, Paint()..color = color.withValues(alpha: 0.15))
        ..drawRect(
          onScreen,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }
  }

  @override
  bool shouldRepaint(_StitchOverlayPainter old) =>
      old.matrix != matrix || old.blocks != blocks || old.area != area || old.color != color;
}
