import 'dart:math' as math;

import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/presentation/editor/editor_state.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

/// Полотно редактора: схема с зумом и сдвигом, мазки одним пальцем (или мышью), два пальца — зум и сдвиг.
///
/// Касания переводятся в ячейки через ту же [GridScene], что и рисование, поэтому попадание верно при любом зуме и для
/// пейота и кирпичика. Колесо и жесты трекпада двигают и масштабируют схему.
class EditorCanvas extends StatefulWidget {
  const EditorCanvas({
    required this.pattern,
    required this.tool,
    required this.showSymbols,
    required this.selection,
    required this.onTap,
    required this.onStrokeStart,
    required this.onStrokeCell,
    required this.onStrokeEnd,
    required this.onSelect,
    this.controller,
    super.key,
  });

  final GridPattern pattern;
  final EditorTool tool;
  final bool showSymbols;
  final CellRect? selection;

  /// Одиночное касание без движения (для заливки, пипетки, замены цвета).
  final ValueChanged<CellPosition> onTap;
  final VoidCallback onStrokeStart;
  final ValueChanged<CellPosition> onStrokeCell;
  final VoidCallback onStrokeEnd;

  /// Рамка выделения: угол нажатия и текущая ячейка.
  final void Function(CellPosition anchor, CellPosition current) onSelect;

  /// Зум и сдвиг снаружи (тесты); иначе полотно ведёт своё преобразование.
  final TransformationController? controller;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  static const double _minScale = 0.25;
  static const double _maxScale = 10;
  static const double _tapSlop = 8;

  TransformationController? _own;
  final Map<int, Offset> _pointers = <int, Offset>{};
  late GridScene _scene = _buildScene();
  bool _fitted = false;

  // Состояние одного касания.
  int? _primary;
  Offset? _downAt;
  bool _moved = false;
  bool _drawing = false;
  CellPosition? _anchor;
  bool _gestureMode = false;

  TransformationController get _controller => widget.controller ?? (_own ??= TransformationController());

  GridScene _buildScene() => GridScene(
    geometry: widget.pattern.geometry,
    metrics: widget.pattern.metrics,
    columns: widget.pattern.grid.width,
    rows: widget.pattern.grid.height,
  );

  @override
  void didUpdateWidget(EditorCanvas oldWidget) {
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
    _own?.dispose();
    super.dispose();
  }

  void _fit(Size viewport) {
    if (_fitted) return;
    _fitted = true;
    final double scale = math.min(3, viewport.width / _scene.size.width);
    final double dx = math.max(0, (viewport.width - _scene.size.width * scale) / 2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.value = Matrix4.identity()
        ..translateByDouble(dx, 0, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    });
  }

  CellPosition? _cellAt(Offset local) {
    final Matrix4 inverse = Matrix4.tryInvert(_controller.value) ?? Matrix4.identity();
    return _scene.cellAt(MatrixUtils.transformPoint(inverse, local));
  }

  bool get _paints => widget.tool == EditorTool.brush || widget.tool == EditorTool.eraser;

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length > 1) {
      _enterGestureMode();
      return;
    }
    _primary = e.pointer;
    _downAt = e.localPosition;
    _moved = false;
    _gestureMode = false;
    final CellPosition? cell = _cellAt(e.localPosition);
    if (_paints) {
      widget.onStrokeStart();
      _drawing = true;
      if (cell != null) widget.onStrokeCell(cell);
    } else if (widget.tool == EditorTool.selection) {
      _anchor = cell;
      if (cell != null) widget.onSelect(cell, cell);
    }
  }

  void _enterGestureMode() {
    _gestureMode = true;
    _endStroke();
    _anchor = null;
  }

  void _endStroke() {
    if (_drawing) {
      _drawing = false;
      widget.onStrokeEnd();
    }
  }

  void _move(PointerMoveEvent e) {
    final Offset? before = _pointers[e.pointer];
    if (before == null) return;
    if (_gestureMode && _pointers.length >= 2) {
      _pinch(e, before);
      return;
    }
    _pointers[e.pointer] = e.localPosition;
    if (e.pointer != _primary || _gestureMode) return;
    if (!_moved && (e.localPosition - _downAt!).distance > _tapSlop) _moved = true;
    final CellPosition? cell = _cellAt(e.localPosition);
    if (cell == null) return;
    if (_drawing) {
      widget.onStrokeCell(cell);
    } else if (widget.tool == EditorTool.selection && _anchor != null) {
      widget.onSelect(_anchor!, cell);
    }
  }

  /// Два пальца: сдвиг по центру и масштаб по расстоянию между ними.
  void _pinch(PointerMoveEvent e, Offset before) {
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

  /// Масштаб вокруг [focal] и сдвиг [pan] в координатах экрана; зум ограничен.
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
    if (_pointers.isEmpty) _gestureMode = false;
    if (!wasPrimary) return;
    _primary = null;
    _endStroke();
    if (!_moved && !_paints && widget.tool != EditorTool.selection) {
      final CellPosition? cell = _cellAt(e.localPosition);
      if (cell != null) widget.onTap(cell);
    }
  }

  void _cancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) _gestureMode = false;
    if (e.pointer == _primary) {
      _primary = null;
      _endStroke();
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _fit(Size(constraints.maxWidth, constraints.maxHeight));
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
                  child: GridPatternView(
                    grid: widget.pattern.grid,
                    palette: widget.pattern.palette,
                    geometry: widget.pattern.geometry,
                    metrics: widget.pattern.metrics,
                    controller: _controller,
                    gesturesEnabled: false,
                    maxScale: _maxScale,
                    options: GridViewOptions(showSymbols: widget.showSymbols),
                  ),
                ),
                if (widget.selection != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CustomPaint(
                          key: const ValueKey<String>('editor-selection'),
                          painter: _SelectionPainter(
                            rect: _selectionRect(widget.selection!),
                            matrix: _controller.value,
                            color: context.tokens.accent.resolveFrom(context),
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

  Rect _selectionRect(CellRect r) {
    final Rect a = _scene.cellRect(CellPosition(r.left, r.top));
    final Rect b = _scene.cellRect(CellPosition(r.right, r.bottom));
    final Rect c = _scene.cellRect(CellPosition(r.left, r.bottom));
    final Rect d = _scene.cellRect(CellPosition(r.right, r.top));
    return a.expandToInclude(b).expandToInclude(c).expandToInclude(d);
  }
}

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({required this.rect, required this.matrix, required this.color});

  final Rect rect;
  final Matrix4 matrix;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect onScreen = MatrixUtils.transformRect(matrix, rect);
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

  @override
  bool shouldRepaint(_SelectionPainter old) => old.rect != rect || old.matrix != matrix || old.color != color;
}
