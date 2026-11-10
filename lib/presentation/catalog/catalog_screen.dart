import 'dart:math' as math;

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/use_cases/find_similar_colors.dart';
import 'package:beading/presentation/catalog/catalog_cubit.dart';
import 'package:beading/presentation/catalog/catalog_labels.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:beading/presentation/widgets/glass/glass_sheet.dart';
import 'package:beading/presentation/widgets/glass/glass_surface.dart';
import 'package:beading/presentation/widgets/min_tap_target.dart';
import 'package:beading/presentation/widgets/pill_chip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Каталог цветов: вкладки брендов, поиск по артикулу и названию, сетка образцов. Нажатие на образец открывает лист
/// с цветом и пятью похожими («подобрать похожий»).
///
/// Ждёт [CatalogCubit] в дереве выше.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  static const String routePath = '/catalog';

  /// Самая широкая колонка контента: на окне Mac сетка не растягивается на весь экран.
  static const double maxContentWidth = 960;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openSheet(CatalogCubit cubit, CatalogColor color) async {
    final Future<void> selecting = cubit.select(color);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => BlocProvider<CatalogCubit>.value(value: cubit, child: const _ColorSheet()),
    );
    cubit.clearSelection();
    await selecting;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final CatalogCubit cubit = context.read<CatalogCubit>();

    return CupertinoPageScaffold(
      child: BlocBuilder<CatalogCubit, CatalogState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.tabs != current.tabs ||
            previous.tab != current.tab ||
            previous.colors != current.colors,
        builder: (context, state) {
          final double width = MediaQuery.sizeOf(context).width;
          final double side = math.max(tokens.spacing.l, (width - CatalogScreen.maxContentWidth) / 2);
          final EdgeInsets inset = EdgeInsets.symmetric(horizontal: side);
          return CustomScrollView(
            slivers: <Widget>[
              CupertinoSliverNavigationBar(largeTitle: Text(cubit.material.title(l10n))),
              SliverPadding(
                padding: inset.copyWith(top: tokens.spacing.s, bottom: tokens.spacing.s),
                sliver: SliverToBoxAdapter(
                  child: CupertinoSearchTextField(
                    controller: _search,
                    placeholder: l10n.catalogSearchPlaceholder,
                    onChanged: cubit.setQuery,
                  ),
                ),
              ),
              if (state.tabs.length > 1)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: side),
                    child: Row(
                      children: <Widget>[
                        PillChip(
                          label: l10n.catalogAllBrands,
                          selected: state.tab == null,
                          onTap: () => cubit.selectTab(null),
                        ),
                        for (final CatalogTab tab in state.tabs)
                          PillChip(label: tab.label, selected: state.tab == tab, onTap: () => cubit.selectTab(tab)),
                      ],
                    ),
                  ),
                ),
              ..._body(context, state, inset, (color) => _openSheet(cubit, color)),
              SliverToBoxAdapter(child: SizedBox(height: tokens.spacing.xxl)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body(BuildContext context, CatalogState state, EdgeInsets inset, void Function(CatalogColor) onPick) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;

    Widget message(String title, {String? text, VoidCallback? onRetry}) => SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            ),
            if (text != null) ...<Widget>[
              SizedBox(height: tokens.spacing.s),
              Text(
                text,
                textAlign: TextAlign.center,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ],
            if (onRetry != null) CupertinoButton(onPressed: onRetry, child: Text(l10n.libraryRetry)),
          ],
        ),
      ),
    );

    switch (state.status) {
      case CatalogStatus.loading:
        return const <Widget>[
          SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator())),
        ];
      case CatalogStatus.failure:
        return <Widget>[
          message(
            l10n.catalogLoadFailedTitle,
            text: l10n.actionFailedGeneric,
            onRetry: context.read<CatalogCubit>().retry,
          ),
        ];
      case CatalogStatus.ready:
        if (state.colors.isEmpty) {
          return <Widget>[message(l10n.catalogEmptyTitle, text: l10n.catalogEmptyMessage)];
        }
        return <Widget>[
          SliverPadding(
            padding: inset.copyWith(top: tokens.spacing.m),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: tokens.spacing.m,
                crossAxisSpacing: tokens.spacing.m,
                mainAxisExtent: 148 + (MediaQuery.textScalerOf(context).scale(41) - 41),
              ),
              itemCount: state.colors.length,
              itemBuilder: (context, index) {
                final CatalogColor color = state.colors[index];
                return _ColorTile(key: ValueKey<String>('color-${color.id}'), color: color, onTap: () => onPick(color));
              },
            ),
          ),
        ];
    }
  }
}

/// Образец с артикулом и названием. Непрозрачная плитка: стекло только на слое управления.
class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.color, required this.onTap, super.key});

  final CatalogColor color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    return Semantics(
      button: true,
      label: l10n.catalogItemSemantic(color.code, color.name),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(tokens.radius.m),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Center(child: ColorSwatchView(rgb: color.rgb, size: 56)),
                ),
                SizedBox(height: tokens.spacing.xs),
                Text(
                  color.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  color.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: base.copyWith(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Лист цвета: крупный образец, откуда он, и пять похожих с мерой похожести.
class _ColorSheet extends StatelessWidget {
  const _ColorSheet();

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 560),
        child: GlassSheet(
          density: GlassDensity.dense,
          child: BlocBuilder<CatalogCubit, CatalogState>(
            buildWhen: (previous, current) => previous.selection != current.selection && current.selection != null,
            builder: (context, state) {
              final SimilarSelection? selection = state.selection;
              if (selection == null) return const SizedBox.shrink();
              return Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _SheetHeader(color: selection.source),
                      SizedBox(height: tokens.spacing.l),
                      _SimilarList(selection: selection),
                      SizedBox(height: tokens.spacing.m),
                      Text(
                        AppLocalizations.of(context).catalogColorApproximate,
                        style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        ),
                      ),
                      CupertinoButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(AppLocalizations.of(context).catalogClose),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.color});

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
      child: Row(
        children: <Widget>[
          ColorSwatchView(rgb: color.rgb, size: 72),
          SizedBox(width: tokens.spacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(color.code, style: base.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
                Text(color.name, style: base.copyWith(fontSize: 17)),
                Text(color.origin(l10n), style: base.copyWith(fontSize: 15, color: secondary)),
                Text(color.rgb.hex, style: base.copyWith(fontSize: 15, color: secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarList extends StatelessWidget {
  const _SimilarList({required this.selection});

  final SimilarSelection selection;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    final List<SimilarColor>? matches = selection.matches;
    final Widget content;
    if (selection.failure != null) {
      content = Text(l10n.catalogSimilarFailed, style: base.copyWith(color: secondary));
    } else if (matches == null) {
      content = const Center(child: CupertinoActivityIndicator());
    } else if (matches.isEmpty) {
      content = Text(l10n.catalogSimilarNone, style: base.copyWith(color: secondary));
    } else {
      content = Column(
        children: <Widget>[
          for (final SimilarColor match in matches)
            _SimilarRow(
              match: match,
              onTap: () => context.read<CatalogCubit>().select(match.color),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          l10n.catalogSimilarTitle,
          style: base.copyWith(fontSize: 13, color: secondary, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: tokens.spacing.s),
        content,
      ],
    );
  }
}

class _SimilarRow extends StatelessWidget {
  const _SimilarRow({required this.match, required this.onTap});

  final SimilarColor match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final CatalogColor color = match.color;
    final String level = match.similarity.level.label(l10n);
    final bool large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    Widget measure(CrossAxisAlignment alignment) => Column(
      crossAxisAlignment: alignment,
      children: <Widget>[
        Text(
          l10n.catalogSimilarityPercent(match.similarity.percent),
          style: base.merge(tokens.counterTextStyle).copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        Text(level, style: base.copyWith(fontSize: 13, color: secondary)),
      ],
    );
    return Semantics(
      button: true,
      label: l10n.catalogSimilaritySemantic(color.code, color.name, match.similarity.percent, level),
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MinTapTarget(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    ColorSwatchView(rgb: color.rgb, size: 36),
                    SizedBox(width: tokens.spacing.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${color.brand} ${color.code}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            color.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: base.copyWith(fontSize: 13, color: secondary),
                          ),
                        ],
                      ),
                    ),
                    if (!large) ...<Widget>[SizedBox(width: tokens.spacing.m), measure(CrossAxisAlignment.end)],
                  ],
                ),
                if (large)
                  Padding(
                    padding: EdgeInsets.only(left: 36 + tokens.spacing.m),
                    child: measure(CrossAxisAlignment.start),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
