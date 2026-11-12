import 'dart:async';
import 'dart:math' as math;

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/presentation/catalog/catalog_cubit.dart';
import 'package:beading/presentation/catalog/catalog_labels.dart';
import 'package:beading/presentation/catalog/color_detail_sheet.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:beading/presentation/widgets/pill_chip.dart';
import 'package:beading/presentation/widgets/stock_stepper.dart';
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
    await showColorDetailSheet(context, cubit);
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
            previous.colors != current.colors ||
            previous.stock != current.stock,
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
                return _ColorTile(
                  key: ValueKey<String>('color-${color.id}'),
                  color: color,
                  onTap: () => onPick(color),
                  haveSkeins: state.stock[CatalogRef(brand: color.brand, code: color.code)],
                );
              },
            ),
          ),
        ];
    }
  }
}

/// Образец с артикулом и названием. Непрозрачная плитка: стекло только на слое управления.
class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.color, required this.onTap, this.haveSkeins, super.key});

  final CatalogColor color;

  /// Мотков в запасе; `null` — нитки в запасе нет.
  final double? haveSkeins;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    return Semantics(
      button: true,
      label: haveSkeins == null
          ? l10n.catalogItemSemantic(color.code, color.name)
          : '${l10n.catalogItemSemantic(color.code, color.name)}, ${l10n.catalogStockBadgeSemantic(StockStepper.amountText(l10n, haveSkeins!))}',
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
                  child: Stack(
                    children: <Widget>[
                      Center(child: ColorSwatchView(rgb: color.rgb, size: 56)),
                      if (haveSkeins != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGreen.resolveFrom(context),
                              borderRadius: BorderRadius.circular(tokens.radius.s),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Text(
                                StockStepper.amountText(l10n, haveSkeins!),
                                style: base.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
