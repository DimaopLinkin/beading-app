import 'dart:math' as math;

import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/presentation/book_work/book_work_cubit.dart';
import 'package:beading/presentation/book_work/book_work_state.dart';
import 'package:beading/presentation/book_work/ruler_colors.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_sheet.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Нижние листы экрана работы по схеме. Листы живут выше экрана в навигаторе, поэтому [BookWorkCubit] передаётся явно.
Future<void> showRulerSettingsSheet(BuildContext context, BookWorkCubit cubit) =>
    _showSheet(context, cubit, (_) => const _RulerSettingsSheet());

Future<void> showNotesSheet(BuildContext context, BookWorkCubit cubit) =>
    _showSheet(context, cubit, (_) => const _NotesSheet());

Future<void> showPagesSheet(BuildContext context, BookWorkCubit cubit) =>
    _showSheet(context, cubit, (_) => const _PagesSheet());

Future<void> _showSheet(BuildContext context, BookWorkCubit cubit, WidgetBuilder builder) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => BlocProvider<BookWorkCubit>.value(
        value: cubit,
        child: SafeArea(
          top: false,
          minimum: EdgeInsets.all(popupContext.tokens.spacing.s),
          // Лист на всю ширину, но не шире 520 pt: на широком окне macOS он остаётся листом, а не полосой.
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox(width: double.infinity, child: builder(popupContext)),
            ),
          ),
        ),
      ),
    );

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Row(
      children: <Widget>[
        Expanded(child: Text(title, style: CupertinoTheme.of(context).textTheme.navTitleTextStyle)),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(context.tokens.minTapTarget),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.bookWorkDone),
        ),
      ],
    );
  }
}

class _RulerSettingsSheet extends StatelessWidget {
  const _RulerSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BookWorkCubit cubit = context.read<BookWorkCubit>();
    final double gap = context.tokens.spacing.m;
    return GlassSheet(
      density: GlassDensity.dense,
      child: SingleChildScrollView(
        child: BlocBuilder<BookWorkCubit, BookWorkState>(
          builder: (context, state) {
            final RulerState ruler = state.work.ruler;
            // Верхний предел: пятая часть страницы, чтобы линейка оставалась линейкой.
            final double limit = math.max(RulerState.minHeight * 2, state.page.height * 0.2);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SheetHeader(title: l10n.bookWorkRulerSettings),
                SizedBox(height: gap),
                Text(l10n.bookWorkDirection),
                SizedBox(height: gap),
                CupertinoSlidingSegmentedControl<RowDirection>(
                  key: const ValueKey<String>('direction-control'),
                  groupValue: ruler.direction,
                  onValueChanged: (value) {
                    if (value != null) {
                      cubit.setDirection(value);
                    }
                  },
                  children: <RowDirection, Widget>{
                    RowDirection.topDown: Padding(
                      padding: EdgeInsets.symmetric(vertical: gap / 2),
                      child: Text(l10n.bookWorkDirectionDown),
                    ),
                    RowDirection.bottomUp: Padding(
                      padding: EdgeInsets.symmetric(vertical: gap / 2),
                      child: Text(l10n.bookWorkDirectionUp),
                    ),
                  },
                ),
                SizedBox(height: gap),
                _LabeledSlider(
                  label: l10n.bookWorkRulerHeight,
                  sliderKey: const ValueKey<String>('ruler-height-slider'),
                  value: ruler.height,
                  min: RulerState.minHeight,
                  max: limit,
                  onChanged: cubit.setRulerHeight,
                ),
                _LabeledSlider(
                  label: l10n.bookWorkRulerStep,
                  sliderKey: const ValueKey<String>('ruler-step-slider'),
                  value: ruler.step,
                  min: RulerState.minStep,
                  max: limit,
                  onChanged: cubit.setRulerStep,
                ),
                SizedBox(height: gap),
                _ZoneSection(ruler: ruler, pageHeight: state.page.height.toDouble()),
                SizedBox(height: gap),
                Text(l10n.bookWorkRulerColor),
                SizedBox(height: gap),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    for (final RulerHighlight highlight in RulerHighlight.values)
                      _ColorSwatch(
                        highlight: highlight,
                        label: _colorName(l10n, highlight),
                        selected: ruler.highlight == highlight,
                        onTap: () => cubit.setHighlight(highlight),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _colorName(AppLocalizations l10n, RulerHighlight highlight) => switch (highlight) {
    RulerHighlight.yellow => l10n.bookWorkColorYellow,
    RulerHighlight.green => l10n.bookWorkColorGreen,
    RulerHighlight.blue => l10n.bookWorkColorBlue,
    RulerHighlight.pink => l10n.bookWorkColorPink,
  };
}

/// Границы схемы на странице и число рядов в них: по числу рядов высота и шаг считаются сами.
class _ZoneSection extends StatelessWidget {
  const _ZoneSection({required this.ruler, required this.pageHeight});

  final RulerState ruler;
  final double pageHeight;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BookWorkCubit cubit = context.read<BookWorkCubit>();
    final double gap = context.tokens.spacing.m;
    final int? count = ruler.rowCount;
    final double span = ruler.zone?.height ?? pageHeight;
    // С чего начать счёт: сколько рядов сейчас помещается по высоте полосы.
    final int guess = math.max(1, (span / math.max(ruler.height, RulerState.minHeight)).round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(l10n.bookWorkZoneTitle, style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
        SizedBox(height: gap),
        Row(
          children: <Widget>[
            Expanded(
              child: CupertinoButton.tinted(
                key: const ValueKey<String>('zone-edit'),
                minimumSize: Size.fromHeight(context.tokens.minTapTarget),
                onPressed: () {
                  Navigator.of(context).pop();
                  cubit.startZoneEditing();
                },
                child: Text(l10n.bookWorkZoneEdit),
              ),
            ),
            if (ruler.zone != null) ...<Widget>[
              SizedBox(width: gap),
              CupertinoButton(
                key: const ValueKey<String>('zone-clear'),
                minimumSize: Size.square(context.tokens.minTapTarget),
                onPressed: cubit.resetZone,
                child: Text(l10n.bookWorkZoneReset),
              ),
            ],
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: <Widget>[
            Expanded(child: Text(l10n.bookWorkZoneRowCount)),
            CupertinoButton(
              key: const ValueKey<String>('row-count-less'),
              minimumSize: Size.square(context.tokens.minTapTarget),
              padding: EdgeInsets.zero,
              onPressed: count == null || count <= 1 ? null : () => cubit.setRowCount(count - 1),
              child: Semantics(label: l10n.bookWorkZoneLess, child: const Icon(AppIcons.zoneMinus)),
            ),
            SizedBox(
              width: 64,
              child: Text(
                count == null ? l10n.bookWorkZoneRowCountUnset : '$count',
                key: const ValueKey<String>('row-count-value'),
                textAlign: TextAlign.center,
              ),
            ),
            CupertinoButton(
              key: const ValueKey<String>('row-count-more'),
              minimumSize: Size.square(context.tokens.minTapTarget),
              padding: EdgeInsets.zero,
              onPressed: () => cubit.setRowCount(count == null ? guess : count + 1),
              child: Semantics(label: l10n.bookWorkZoneMore, child: const Icon(AppIcons.add)),
            ),
          ],
        ),
        if (count != null)
          Row(
            children: <Widget>[
              Expanded(child: Text(l10n.bookWorkZoneRowCountAuto)),
              CupertinoButton(
                key: const ValueKey<String>('row-count-manual'),
                minimumSize: Size.square(context.tokens.minTapTarget),
                onPressed: () => cubit.setRowCount(null),
                child: Text(l10n.bookWorkZoneRowCountManual),
              ),
            ],
          ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.sliderKey,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final Key sliderKey;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.tokens.minTapTarget),
          child: Semantics(
            label: label,
            child: CupertinoSlider(
              key: sliderKey,
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({required this.highlight, required this.label, required this.selected, required this.onTap});

  final RulerHighlight highlight;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double size = context.tokens.minTapTarget;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: ValueKey<String>('ruler-color-${highlight.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: size + 8,
          child: Center(
            child: Container(
              width: size - 4,
              height: size - 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: RulerColors.swatch(context, highlight),
                border: selected
                    ? Border.all(color: CupertinoColors.label.resolveFrom(context), width: 3)
                    : Border.all(color: CupertinoColors.separator.resolveFrom(context)),
              ),
              child: selected ? const Icon(AppIcons.selected, color: CupertinoColors.white) : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesSheet extends StatefulWidget {
  const _NotesSheet();

  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  late final TextEditingController _controller = TextEditingController(text: context.read<BookWorkCubit>().state.notes);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BookWorkCubit cubit = context.read<BookWorkCubit>();
    final double gap = context.tokens.spacing.m;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: GlassSheet(
        density: GlassDensity.dense,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SheetHeader(title: l10n.bookWorkNotes),
            SizedBox(height: gap),
            CupertinoTextField(
              key: const ValueKey<String>('notes-field'),
              controller: _controller,
              placeholder: l10n.bookWorkNotesHint,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              onChanged: cubit.updateNotes,
            ),
          ],
        ),
      ),
    );
  }
}

class _PagesSheet extends StatelessWidget {
  const _PagesSheet();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final BookWorkCubit cubit = context.read<BookWorkCubit>();
    final BookWorkState state = cubit.state;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.6;
    return GlassSheet(
      density: GlassDensity.dense,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _SheetHeader(title: l10n.bookWorkPagesTitle),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.pages.length,
                itemBuilder: (context, index) {
                  final bool current = index == state.pageIndex;
                  return Semantics(
                    button: true,
                    selected: current,
                    label: l10n.bookWorkPageItem(index + 1),
                    excludeSemantics: true,
                    onTap: () {
                      cubit.selectPage(index);
                      Navigator.of(context).pop();
                    },
                    child: GestureDetector(
                      key: ValueKey<String>('page-item-$index'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        cubit.selectPage(index);
                        Navigator.of(context).pop();
                      },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: context.tokens.minTapTarget),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: Text(l10n.bookWorkPageItem(index + 1))),
                            if (current) Icon(AppIcons.selected, color: context.tokens.accent.resolveFrom(context)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
