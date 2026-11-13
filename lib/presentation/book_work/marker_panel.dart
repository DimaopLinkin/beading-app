import 'package:beading/domain/image_pattern/book_work/page_markup.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/book_work/book_work_state.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Высота нижней панели в режиме маркера (макет 11: 178 pt).
const double markerPanelHeight = 178;

/// Нижняя панель режима «Маркер»: возврат к линейке, цвета, ластик, толщина, «Отменить», «Вернуть», показ пометок.
class MarkerPanel extends StatelessWidget {
  const MarkerPanel({required this.state, super.key});

  final BookWorkState state;

  static const double _swatch = 32;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final BookWorkCubit cubit = context.read<BookWorkCubit>();
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final List<String> colorNames = <String>[
      l10n.bookWorkMarkerYellow,
      l10n.bookWorkMarkerPink,
      l10n.bookWorkMarkerBlue,
      l10n.bookWorkMarkerGreen,
      l10n.bookWorkMarkerOrange,
    ];
    final List<String> widthNames = <String>[
      l10n.bookWorkMarkerThin,
      l10n.bookWorkMarkerMedium,
      l10n.bookWorkMarkerWide,
    ];
    final bool empty = state.work.markup.isEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.s),
        child: GlassPanel(
          key: const ValueKey<String>('marker-panel'),
          density: GlassDensity.dense,
          padding: EdgeInsets.all(tokens.spacing.s),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _LabelButton(
                    key: const ValueKey<String>('marker-back'),
                    icon: AppIcons.back,
                    label: l10n.bookWorkMarkerBack,
                    onPressed: cubit.finishMarker,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(l10n.bookWorkMarker, style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
                        Text(
                          empty ? l10n.bookWorkMarkerEmpty : l10n.bookWorkMarkerHint,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: base.copyWith(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    key: const ValueKey<String>('marker-done'),
                    padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
                    minimumSize: Size.square(tokens.minTapTarget),
                    onPressed: cubit.finishMarker,
                    child: Text(l10n.bookWorkDone),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final (int i, int rgb) in MarkerPalette.colors.indexed)
                    _Swatch(
                      key: ValueKey<String>('marker-color-$i'),
                      rgb: rgb,
                      label: colorNames[i],
                      selected: !state.markerEraser && state.markerColor == i,
                      onPressed: () => cubit.setMarkerColor(i),
                    ),
                  _LabelButton(
                    key: const ValueKey<String>('marker-eraser'),
                    icon: AppIcons.eraser,
                    label: l10n.bookWorkMarkerEraser,
                    selected: state.markerEraser,
                    onPressed: () => cubit.setMarkerEraser(eraser: !state.markerEraser),
                  ),
                ],
              ),
              SizedBox(height: tokens.spacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final (int i, double w) in MarkerPalette.widths.indexed)
                    _LabelButton(
                      key: ValueKey<String>('marker-width-$i'),
                      // Кружок-предпросмотр: размер растёт вместе с толщиной.
                      iconWidget: Container(
                        width: 8.0 + w * 700,
                        height: 8.0 + w * 700,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF000000 | MarkerPalette.colors[state.markerColor]),
                          border: Border.all(color: CupertinoColors.separator.resolveFrom(context), width: 0.5),
                        ),
                      ),
                      label: widthNames[i],
                      selected: state.markerWidth == i,
                      onPressed: () => cubit.setMarkerWidth(i),
                    ),
                  _LabelButton(
                    key: const ValueKey<String>('marker-undo'),
                    icon: AppIcons.undo,
                    label: l10n.bookWorkMarkerUndo,
                    onPressed: state.canUndoMarkup ? cubit.undoMarkup : null,
                  ),
                  _LabelButton(
                    key: const ValueKey<String>('marker-redo'),
                    icon: AppIcons.redo,
                    label: l10n.bookWorkMarkerRedo,
                    onPressed: state.canRedoMarkup ? cubit.redoMarkup : null,
                  ),
                  _LabelButton(
                    key: const ValueKey<String>('marker-show'),
                    icon: state.showMarkup ? AppIcons.eye : AppIcons.eyeOff,
                    label: l10n.bookWorkMarkerShow,
                    selected: state.showMarkup,
                    onPressed: cubit.toggleShowMarkup,
                    onLongPress: empty ? null : () => confirmClearMarkup(context, cubit),
                    customActionLabel: empty ? null : l10n.bookWorkMarkerClear,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Очистить страницу»: системный лист с красным действием; пометки можно вернуть кнопкой «Вернуть».
Future<void> confirmClearMarkup(BuildContext context, BookWorkCubit cubit) {
  final AppLocalizations l10n = AppLocalizations.of(context);
  final int count = cubit.state.work.markup.strokes.length;
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      message: Text(l10n.bookWorkMarkerClearMessage(count)),
      actions: <Widget>[
        CupertinoActionSheetAction(
          key: const ValueKey<String>('marker-clear-confirm'),
          isDestructiveAction: true,
          onPressed: () {
            cubit.clearMarkup();
            Navigator.of(sheetContext).pop();
          },
          child: Text(l10n.bookWorkMarkerClear),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: Text(l10n.cancel),
      ),
    ),
  );
}

/// Кнопка с подписью 13 pt под значком; выбранная — в рамке цвета акцента.
class _LabelButton extends StatelessWidget {
  const _LabelButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.selected = false,
    this.onLongPress,
    this.customActionLabel,
    super.key,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? customActionLabel;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final Color accent = tokens.accent.resolveFrom(context);
    final bool enabled = onPressed != null;
    final Color color = enabled
        ? CupertinoColors.label.resolveFrom(context)
        : CupertinoColors.tertiaryLabel.resolveFrom(context);
    // Flexible: на узкой ширине или крупном шрифте подписи усекаются, а не вылезают за панель.
    return Flexible(
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        onLongPress: onLongPress,
        customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
          if (onLongPress != null && customActionLabel != null)
            CustomSemanticsAction(label: customActionLabel!): onLongPress!,
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: tokens.minTapTarget, minHeight: tokens.minTapTarget),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(tokens.radius.s),
                border: Border.all(color: selected ? accent : const Color(0x00000000), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(
                      height: 24,
                      child: Center(child: iconWidget ?? Icon(icon, size: 22, color: selected ? accent : color)),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                        fontSize: 13,
                        color: selected ? accent : color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Образец цвета маркера; выбранный — с двойным кольцом, название слышит VoiceOver.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.rgb, required this.label, required this.selected, required this.onPressed, super.key});

  final int rgb;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final Color accent = tokens.accent.resolveFrom(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: tokens.minTapTarget,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? accent : const Color(0x00000000), width: 2),
              ),
              child: Container(
                width: MarkerPanel._swatch,
                height: MarkerPanel._swatch,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF000000 | rgb).withValues(alpha: markerSwatchOpacity),
                  border: Border.all(color: CupertinoColors.separator.resolveFrom(context), width: 0.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Образец чуть плотнее мазка, чтобы цвет читался на светлой панели.
const double markerSwatchOpacity = 0.85;
