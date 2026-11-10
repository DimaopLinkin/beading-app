import 'dart:math' as math;

import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/presentation/grid_pattern/grid_base_painter.dart';
import 'package:beading/presentation/grid_pattern/grid_colors.dart';
import 'package:beading/presentation/grid_pattern/grid_layer_cache.dart';
import 'package:beading/presentation/grid_pattern/grid_overlay_painter.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Сеточная схема: бусины или крестики, зум и сдвиг, подсветка текущего ряда.
///
/// Рисует только видимую область; слой ячеек кешируется в `Picture` блоками и не перестраивается, пока схема,
/// палитра и настройки показа те же. Касания отдаёт в координатах ячейки ([onCellTap], [onCellLongPress]) через
/// геометрию схемы, поэтому они верны при любом зуме и для пейота и кирпичного стежка.
class GridPatternView extends StatefulWidget {
  const GridPatternView({
    required this.grid,
    required this.palette,
    required this.geometry,
    required this.metrics,
    this.options = const GridViewOptions(),
    this.controller,
    this.onCellTap,
    this.onCellLongPress,
    this.interactive = true,
    this.maxScale = 8,
    @visibleForTesting this.layerCache,
    super.key,
  });

  final Grid grid;
  final PaletteSnapshot palette;
  final GridGeometry geometry;
  final CellMetrics metrics;
  final GridViewOptions options;

  /// Зум и сдвиг снаружи (например, чтобы доехать до ряда). Если не задан, вид сам вписывается по ширине.
  final TransformationController? controller;

  /// Касание ячейки. Касание вне ячеек (за схемой, в «зубце» сдвинутого края) не вызывает.
  final ValueChanged<CellPosition>? onCellTap;

  final ValueChanged<CellPosition>? onCellLongPress;

  /// `false` — без зума и сдвига (редактору, которому нужны мазки пальцем).
  final bool interactive;

  /// Наибольший зум относительно размера сцены.
  final double maxScale;

  /// Кеш слоя ячеек снаружи: тесты считают по нему построения. Владелец освобождает его сам.
  final GridLayerCache? layerCache;

  @override
  State<GridPatternView> createState() => _GridPatternViewState();
}

/// Ширина полосы слева под маркер текущего ряда.
const double gridRowGutter = 72;

class _GridPatternViewState extends State<GridPatternView> {
  GridLayerCache? _ownCache;
  TransformationController? _ownController;
  late GridScene _scene = _buildScene();
  int _revision = 0;
  bool _fitted = false;

  GridLayerCache get _cache => widget.layerCache ?? (_ownCache ??= GridLayerCache());

  TransformationController get _controller => widget.controller ?? (_ownController ??= TransformationController());

  GridScene _buildScene() => GridScene(
    geometry: widget.geometry,
    metrics: widget.metrics,
    columns: widget.grid.width,
    rows: widget.grid.height,
  );

  @override
  void didUpdateWidget(GridPatternView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _fitted = false;
    if (oldWidget.geometry != widget.geometry ||
        oldWidget.metrics != widget.metrics ||
        oldWidget.grid.width != widget.grid.width ||
        oldWidget.grid.height != widget.grid.height) {
      _scene = _buildScene();
      _fitted = false;
    }
  }

  @override
  void dispose() {
    _ownCache?.dispose();
    _ownController?.dispose();
    super.dispose();
  }

  GridPaintStyle _style(BuildContext context) => GridPaintStyle(
    line: GridColors.line.resolveFrom(context),
    boldLine: GridColors.boldLine.resolveFrom(context),
    emptyCell: GridColors.emptyCell.resolveFrom(context),
    unknown: GridColors.unknown.resolveFrom(context),
  );

  /// Вписывает схему по ширине окна (не крупнее 3×) один раз на схему.
  void _fit(Size viewport) {
    if (widget.controller != null || _fitted) return;
    _fitted = true;
    final double scale = math.min(3, viewport.width / _scene.size.width);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.value = Matrix4.identity()..scaleByDouble(scale, scale, 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final GridPaintStyle style = _style(context);
    final int before = _cache.buildCount;
    _cache.configure(
      grid: widget.grid,
      palette: widget.palette,
      scene: _scene,
      options: widget.options,
      style: style,
    );
    // Слой сброшен конфигурацией — painter должен перерисоваться (счётчик построений не годится: блоки ленивые).
    if (_cache.cachedBlocks == 0 && before == _cache.buildCount) _revision++;
    final Color veil = GridColors.veil.resolveFrom(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Слева полоса под маркер ряда: он стоит вне схемы, на нейтральном фоне.
        final double gutter = widget.interactive && widget.options.currentRow != null ? gridRowGutter : 0;
        final Size viewport = Size(math.max(1, constraints.maxWidth - gutter), constraints.maxHeight);
        _fit(viewport);
        final double fitScale = viewport.width / _scene.size.width;
        final Widget scene = SizedBox(
          width: _scene.size.width,
          height: _scene.size.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey<String>('grid-cells'),
                    painter: GridBasePainter(
                      cache: _cache,
                      controller: _controller,
                      viewportSize: viewport,
                      revision: _revision,
                      wholeScene: !widget.interactive,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: const ValueKey<String>('grid-overlay'),
                    painter: GridOverlayPainter(
                      scene: _scene,
                      options: widget.options,
                      veil: veil,
                      ring: context.tokens.rowRing,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey<String>('grid-touch'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.onCellTap == null ? null : (d) => _emit(d.localPosition, widget.onCellTap!),
                  onLongPressStart: widget.onCellLongPress == null
                      ? null
                      : (d) => _emit(d.localPosition, widget.onCellLongPress!),
                ),
              ),
            ],
          ),
        );
        return ClipRect(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: gutter,
                top: 0,
                right: 0,
                bottom: 0,
                child: widget.interactive
                    ? InteractiveViewer(
                        transformationController: _controller,
                        constrained: false,
                        minScale: math.min(0.1, fitScale / 2),
                        maxScale: math.max(widget.maxScale, fitScale),
                        boundaryMargin: const EdgeInsets.all(64),
                        child: scene,
                      )
                    : FittedBox(alignment: Alignment.topCenter, child: scene),
              ),
              if (widget.interactive && widget.options.currentRow != null)
                _RowMarker(
                  controller: _controller,
                  scene: _scene,
                  row: widget.options.currentRow!,
                  order: widget.options.order,
                  viewport: viewport,
                ),
            ],
          ),
        );
      },
    );
  }

  void _emit(Offset scenePoint, ValueChanged<CellPosition> callback) {
    final CellPosition? cell = _scene.cellAt(scenePoint);
    if (cell != null) callback(cell);
  }
}

/// Маркер текущего ряда у левого края окна: капсула акцента с номером ряда. Стоит вне схемы, на нейтральном фоне, и
/// не масштабируется вместе с ней, поэтому читается при любом зуме.
class _RowMarker extends StatelessWidget {
  const _RowMarker({
    required this.controller,
    required this.scene,
    required this.row,
    required this.viewport,
    this.order,
  });

  final TransformationController controller;
  final GridScene scene;
  final int row;
  final ReadingOrder? order;
  final Size viewport;

  static const double _height = 28;

  @override
  Widget build(BuildContext context) {
    final ReadingOrder? reading = order;
    if (row < 0 || row >= (reading?.rowCount ?? scene.rows)) return const SizedBox.shrink();
    final Rect bounds = reading == null ? scene.rowBounds(row) : scene.cellsBounds(reading.row(row).cells);
    final Color accent = context.tokens.accent.resolveFrom(context);
    final Color onAccent = CupertinoDynamicColor.resolve(CupertinoColors.white, context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final Matrix4 m = controller.value;
        final double centerY = m.transformRect(bounds).center.dy;
        if (centerY < -_height || centerY > viewport.height + _height) return const SizedBox.shrink();
        return Positioned(
          key: const ValueKey<String>('grid-row-marker'),
          left: 6,
          top: centerY - _height / 2,
          child: IgnorePointer(
            child: Container(
              height: _height,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(_height / 2)),
              child: Text(
                AppLocalizations.of(context).gridRowMarker(row + 1),
                style: context.tokens.counterTextStyle.copyWith(
                  color: onAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

extension on Matrix4 {
  Rect transformRect(Rect rect) => MatrixUtils.transformRect(this, rect);
}
