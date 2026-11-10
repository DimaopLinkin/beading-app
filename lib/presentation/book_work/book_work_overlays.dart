import 'dart:async';
import 'dart:math' as math;

import 'package:beading/domain/image_pattern/book_work/pattern_zone.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// Видимый размер «уха» и ручки у линейки (04 v2); зона нажатия — не меньше `minTapTarget`.
const double rulerMarkSize = 30;

/// Метка «Ряд N» («ухо») и ручка высоты у линейки. Лежат вне полосы ряда, на притушенном пройденном ряду и на
/// следующем, поэтому бусины текущего ряда остаются открытыми. При ходе снизу вверх ухо и ручка меняются местами.
///
/// [rulerTop] и [rulerBottom] — экранные координаты полосы линейки; метки прижимаются к области между панелями
/// [minY]…[maxY], когда линейка у края экрана.
class RulerMarks extends StatelessWidget {
  const RulerMarks({
    required this.ruler,
    required this.rulerTop,
    required this.rulerBottom,
    required this.pagePerScreen,
    required this.minY,
    required this.maxY,
    required this.cubit,
    super.key,
  });

  final RulerState ruler;
  final double rulerTop;
  final double rulerBottom;

  /// Сколько пикселей страницы в одном экранном пикселе (для перевода жеста в высоту линейки).
  final double pagePerScreen;
  final double minY;
  final double maxY;
  final BookWorkCubit cubit;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final double zone = tokens.minTapTarget;
    final double gap = (zone - rulerMarkSize) / 2;
    final bool up = ruler.isBottomUp;
    // Зона нажатия центрируется на видимой метке, лежащей вплотную к краю полосы.
    final double above = rulerTop - rulerMarkSize - gap;
    final double below = rulerBottom - gap;
    final double earY = up ? below : above;
    final double handleY = up ? above : below;
    double clamp(double y) => y.clamp(minY - gap, (maxY - rulerMarkSize - gap).clamp(minY - gap, double.infinity));
    return Stack(
      children: <Widget>[
        Positioned(
          left: tokens.spacing.xs,
          top: clamp(earY),
          child: _Ear(row: ruler.row, zone: zone),
        ),
        Positioned(
          right: tokens.spacing.xs,
          top: clamp(handleY),
          child: _Handle(
            zone: zone,
            // Ручка над полосой тянет вверх, под полосой — вниз: потянули от линейки — она выросла.
            onDrag: (dy) => cubit.setRulerHeight(ruler.height + (up ? -dy : dy) * pagePerScreen),
          ),
        ),
      ],
    );
  }
}

/// Четыре ручки по краям рамки схемы. Каждая двигает один край; рамка не вырождается (см. [PatternZone.fitted]).
///
/// [left], [top], [right], [bottom] — экранные координаты краёв рамки; ручка прижимается к видимой области
/// [minY]…[maxY] и [0, width], когда край ушёл за экран из-за зума.
class ZoneHandles extends StatelessWidget {
  const ZoneHandles({
    required this.zone,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.pagePerScreen,
    required this.width,
    required this.minY,
    required this.maxY,
    required this.cubit,
    super.key,
  });

  final PatternZone zone;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double pagePerScreen;
  final double width;
  final double minY;
  final double maxY;
  final BookWorkCubit cubit;

  @override
  Widget build(BuildContext context) {
    final double hit = context.tokens.minTapTarget;
    final double centerX = ((left + right) / 2).clamp(hit / 2, math.max(hit / 2, width - hit / 2));
    final double centerY = ((top + bottom) / 2).clamp(minY + hit / 2, math.max(minY + hit / 2, maxY - hit / 2));
    double x(double v) => v.clamp(hit / 2, math.max(hit / 2, width - hit / 2));
    double y(double v) => v.clamp(minY + hit / 2, math.max(minY + hit / 2, maxY - hit / 2));
    final String label = AppLocalizations.of(context).bookWorkZoneHandle;
    return Stack(
      children: <Widget>[
        _EdgeHandle(
          handleKey: 'zone-handle-top',
          label: label,
          icon: AppIcons.resize,
          center: Offset(centerX, y(top)),
          vertical: true,
          onDrag: (d) => cubit.setZone(zone.copyWith(top: zone.top + d * pagePerScreen)),
        ),
        _EdgeHandle(
          handleKey: 'zone-handle-bottom',
          label: label,
          icon: AppIcons.resize,
          center: Offset(centerX, y(bottom)),
          vertical: true,
          onDrag: (d) => cubit.setZone(zone.copyWith(bottom: zone.bottom + d * pagePerScreen)),
        ),
        _EdgeHandle(
          handleKey: 'zone-handle-left',
          label: label,
          icon: AppIcons.resizeWide,
          center: Offset(x(left), centerY),
          vertical: false,
          onDrag: (d) => cubit.setZone(zone.copyWith(left: zone.left + d * pagePerScreen)),
        ),
        _EdgeHandle(
          handleKey: 'zone-handle-right',
          label: label,
          icon: AppIcons.resizeWide,
          center: Offset(x(right), centerY),
          vertical: false,
          onDrag: (d) => cubit.setZone(zone.copyWith(right: zone.right + d * pagePerScreen)),
        ),
      ],
    );
  }
}

class _EdgeHandle extends StatelessWidget {
  const _EdgeHandle({
    required this.handleKey,
    required this.label,
    required this.icon,
    required this.center,
    required this.vertical,
    required this.onDrag,
  });

  final String handleKey;
  final String label;
  final IconData icon;
  final Offset center;
  final bool vertical;

  /// Смещение пальца вдоль оси ручки, экранные px.
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final double hit = tokens.minTapTarget;
    return Positioned(
      left: center.dx - hit / 2,
      top: center.dy - hit / 2,
      child: Semantics(
        label: label,
        child: GestureDetector(
          key: ValueKey<String>(handleKey),
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: vertical ? (details) => onDrag(details.delta.dy) : null,
          onHorizontalDragUpdate: vertical ? null : (details) => onDrag(details.delta.dx),
          child: SizedBox.square(
            dimension: hit,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(color: tokens.accent.resolveFrom(context), shape: BoxShape.circle),
                child: SizedBox.square(
                  dimension: rulerMarkSize,
                  child: Icon(icon, size: 16, color: CupertinoColors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ear extends StatelessWidget {
  const _Ear({required this.row, required this.zone});

  final int row;
  final double zone;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return IgnorePointer(
      child: SizedBox(
        height: zone,
        child: Center(
          child: DecoratedBox(
            key: const ValueKey<String>('ruler-ear'),
            decoration: BoxDecoration(
              color: tokens.accent.resolveFrom(context),
              borderRadius: BorderRadius.circular(rulerMarkSize / 2),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: rulerMarkSize),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    AppLocalizations.of(context).bookWorkRow(row),
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.zone, required this.onDrag});

  final double zone;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return Semantics(
      label: AppLocalizations.of(context).bookWorkResizeHandle,
      child: GestureDetector(
        key: const ValueKey<String>('ruler-handle'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
        child: SizedBox.square(
          dimension: zone,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.accent.resolveFrom(context),
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(
                dimension: rulerMarkSize,
                child: Icon(AppIcons.resize, size: 16, color: CupertinoColors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Индикатор масштаба (не кнопка) и отдельная кнопка «По ширине» под верхней панелью.
class ZoomChip extends StatelessWidget {
  const ZoomChip({required this.scale, required this.onFitWidth, super.key});

  final double scale;
  final VoidCallback onFitWidth;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final String shown = NumberFormat.decimalPatternDigits(locale: 'ru', decimalDigits: 1).format(scale);
    return GlassPanel(
      density: GlassDensity.dense,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.bookWorkZoomLevel(shown), key: const ValueKey<String>('zoom-level')),
          CupertinoButton(
            key: const ValueKey<String>('fit-width'),
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
            minimumSize: Size.square(tokens.minTapTarget),
            onPressed: onFitWidth,
            child: Text(l10n.bookWorkFitWidth),
          ),
        ],
      ),
    );
  }
}

/// Баннер на последнем ряду страницы.
class PageEndBanner extends StatelessWidget {
  const PageEndBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return GlassPanel(
      key: const ValueKey<String>('page-end-banner'),
      density: GlassDensity.dense,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l, vertical: tokens.spacing.s),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(AppIcons.selected, color: tokens.accent.resolveFrom(context)),
          SizedBox(width: tokens.spacing.s),
          Text(AppLocalizations.of(context).bookWorkPageEnd),
        ],
      ),
    );
  }
}

/// Тост «Ряд N · Отменить». Сам исчезает через [lifetime]; новый ряд пересоздаёт его и отсчёт идёт заново.
class UndoToast extends StatefulWidget {
  const UndoToast({
    required this.row,
    required this.onUndo,
    required this.onDismiss,
    this.lifetime = const Duration(seconds: 5),
    super.key,
  });

  final int row;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;
  final Duration lifetime;

  @override
  State<UndoToast> createState() => _UndoToastState();
}

class _UndoToastState extends State<UndoToast> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.lifetime, widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return GlassPanel(
      density: GlassDensity.dense,
      padding: EdgeInsets.only(left: tokens.spacing.l),
      child: Semantics(
        liveRegion: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l10n.bookWorkRow(widget.row)),
            CupertinoButton(
              key: const ValueKey<String>('undo-row'),
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l),
              minimumSize: Size.square(tokens.minTapTarget),
              onPressed: widget.onUndo,
              child: Text(l10n.bookWorkUndo),
            ),
          ],
        ),
      ),
    );
  }
}
