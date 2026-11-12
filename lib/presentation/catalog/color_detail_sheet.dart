import 'dart:async';

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/use_cases/find_similar_colors.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/presentation/catalog/catalog_cubit.dart';
import 'package:beading/presentation/catalog/catalog_labels.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/app_list_section.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:beading/presentation/widgets/stock_stepper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Показывает системный iOS-лист цвета каталога: образец, «Мой запас» (для ниток) и пять похожих.
/// Лист тянется пальцем и закрывается свайпом вниз, как «Новый проект». Ждёт [cubit] с уже начатым выбором.
Future<void> showColorDetailSheet(BuildContext context, CatalogCubit cubit) => showCupertinoSheet<void>(
  context: context,
  builder: (_) => BlocProvider<CatalogCubit>.value(value: cubit, child: const ColorDetailSheet()),
);

class ColorDetailSheet extends StatelessWidget {
  const ColorDetailSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: BlocBuilder<CatalogCubit, CatalogState>(
          buildWhen: (previous, current) => previous.selection?.source != current.selection?.source,
          builder: (context, state) => Text(state.selection?.source.code ?? ''),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(tokens.minTapTarget),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.catalogClose),
        ),
      ),
      child: SafeArea(
        child: BlocBuilder<CatalogCubit, CatalogState>(
          buildWhen: (previous, current) => previous.selection != current.selection && current.selection != null,
          builder: (context, state) {
            final SimilarSelection? selection = state.selection;
            if (selection == null) return const SizedBox.shrink();
            final CatalogCubit cubit = context.read<CatalogCubit>();
            return ListView(
              children: <Widget>[
                _Header(color: selection.source),
                if (cubit.stockUnit case final StockUnit unit) _StockSection(color: selection.source, unit: unit),
                _SimilarSection(selection: selection),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.color});

  final CatalogColor color;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Semantics(
      header: true,
      container: true,
      label: l10n.catalogItemSemantic(color.code, color.name),
      child: Padding(
        padding: EdgeInsets.fromLTRB(tokens.spacing.l, tokens.spacing.m, tokens.spacing.l, tokens.spacing.s),
        child: Row(
          children: <Widget>[
            ColorSwatchView(rgb: color.rgb, size: 72),
            SizedBox(width: tokens.spacing.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(color.name, style: base.copyWith(fontSize: 20, fontWeight: FontWeight.w700)),
                  Text(color.origin(l10n), style: base.copyWith(fontSize: 15, color: secondary)),
                  Text(color.rgb.hex, style: base.copyWith(fontSize: 15, color: secondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Мой запас»: сколько мотков этой нитки есть. Число меняется сразу, запись идёт следом; ошибка записи видна
/// под счётчиком, а число возвращается к тому, что реально сохранено.
class _StockSection extends StatelessWidget {
  const _StockSection({required this.color, required this.unit});

  final CatalogColor color;
  final StockUnit unit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final CatalogCubit cubit = context.read<CatalogCubit>();
    final CatalogRef ref = CatalogRef(brand: color.brand, code: color.code);
    return BlocBuilder<CatalogCubit, CatalogState>(
      buildWhen: (previous, current) =>
          previous.stock[ref] != current.stock[ref] || previous.stockWriteFailure != current.stockWriteFailure,
      builder: (context, state) => AppListSection(
        header: Text(l10n.catalogStockTitle),
        footer: state.stockWriteFailure == null
            ? null
            : Text(
                unit == StockUnit.grams ? l10n.beadStockWriteFailed : l10n.flossStockWriteFailed,
                style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
              ),
        children: <Widget>[
          _StockRow(
            key: ValueKey<String>('stock-${color.id}'),
            saved: state.stock[ref] ?? 0,
            unit: unit,
            failed: state.stockWriteFailure != null,
            onChanged: (value) => unawaited(cubit.setStock(color, value)),
          ),
        ],
      ),
    );
  }
}

/// Строка со счётчиком мотков. Хранит показанное число сама, чтобы нажатие было видно сразу, не дожидаясь базы.
class _StockRow extends StatefulWidget {
  const _StockRow({required this.saved, required this.unit, required this.failed, required this.onChanged, super.key});

  final double saved;
  final StockUnit unit;
  final bool failed;
  final ValueChanged<double> onChanged;

  @override
  State<_StockRow> createState() => _StockRowState();
}

class _StockRowState extends State<_StockRow> {
  late double _shown = widget.saved;

  @override
  void didUpdateWidget(_StockRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Сохранённое число изменилось (ответ базы или правка на другом экране) или запись не удалась: верим базе.
    if (widget.saved != oldWidget.saved || (widget.failed && !oldWidget.failed)) _shown = widget.saved;
  }

  @override
  Widget build(BuildContext context) => CupertinoListTile(
    title: StockStepper(
      value: _shown,
      unit: widget.unit,
      onChanged: (value) {
        setState(() => _shown = value);
        widget.onChanged(value);
      },
    ),
  );
}

class _SimilarSection extends StatelessWidget {
  const _SimilarSection({required this.selection});

  final SimilarSelection selection;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final List<SimilarColor>? matches = selection.matches;

    Widget note(Widget child) => Padding(padding: EdgeInsets.all(tokens.spacing.l), child: child);

    final List<Widget> children;
    if (selection.failure != null) {
      children = <Widget>[
        CupertinoListTile(
          title: Text(l10n.catalogSimilarFailed, style: base.copyWith(color: secondary)),
        ),
      ];
    } else if (matches == null) {
      children = <Widget>[const CupertinoListTile(title: Center(child: CupertinoActivityIndicator()))];
    } else if (matches.isEmpty) {
      children = <Widget>[
        CupertinoListTile(
          title: Text(l10n.catalogSimilarNone, style: base.copyWith(color: secondary)),
        ),
      ];
    } else {
      children = <Widget>[
        for (final SimilarColor match in matches)
          _SimilarTile(match: match, onTap: () => unawaited(context.read<CatalogCubit>().select(match.color))),
      ];
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppListSection(header: Text(l10n.catalogSimilarTitle), children: children),
        note(Text(l10n.catalogColorApproximate, style: base.copyWith(fontSize: 13, color: secondary))),
      ],
    );
  }
}

class _SimilarTile extends StatelessWidget {
  const _SimilarTile({required this.match, required this.onTap});

  final SimilarColor match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final CatalogColor color = match.color;
    final String level = match.similarity.level.label(l10n);
    // Крупный шрифт: числа не помещаются справа от названия, они уходят в подзаголовок.
    final bool large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final Widget percent = Text(
      l10n.catalogSimilarityPercent(match.similarity.percent),
      style: base.merge(context.tokens.counterTextStyle).copyWith(fontSize: 17, fontWeight: FontWeight.w600),
    );
    final Widget levelText = Text(level, style: base.copyWith(fontSize: 13, color: secondary));
    return Semantics(
      button: true,
      label: l10n.catalogSimilaritySemantic(color.code, color.name, match.similarity.percent, level),
      excludeSemantics: true,
      onTap: onTap,
      child: CupertinoListTile(
        leading: ColorSwatchView(rgb: color.rgb, size: 36),
        title: Text('${color.brand} ${color.code}', maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(color.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  percent,
                  levelText,
                ],
              )
            : Text(color.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        additionalInfo: large
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[percent, levelText],
              ),
        trailing: const CupertinoListTileChevron(),
        onTap: onTap,
      ),
    );
  }
}
