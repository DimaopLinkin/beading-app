import 'dart:async';
import 'dart:math' as math;

import 'package:beading/core/failure.dart';
import 'package:beading/domain/floss_stock/floss_shortage.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/sharing/file_sharer.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:beading/presentation/floss/floss_cubit.dart';
import 'package:beading/presentation/floss/floss_format.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/printing/print_flow.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/app_list_section.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:beading/presentation/widgets/glass/glass_button.dart';
import 'package:beading/presentation/widgets/stock_stepper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Расход мулине для вышивки: канва, список покупок по ниткам, таблица по цветам схемы и «Поделиться».
/// Ждёт [FlossCubit] в дереве выше.
class FlossScreen extends StatefulWidget {
  const FlossScreen({required this.sharer, required this.fileSharer, super.key});

  static const String routePath = '/projects/:projectId/floss';

  static String locationFor(String projectId) => '/projects/$projectId/floss';

  static const double maxContentWidth = 720;

  final TextSharer sharer;
  final FileSharer fileSharer;

  @override
  State<FlossScreen> createState() => _FlossScreenState();
}

class _FlossScreenState extends State<FlossScreen> {
  final GlobalKey _shareKey = GlobalKey();
  final GlobalKey _printKey = GlobalKey();
  bool _printing = false;

  /// Настройки печати, сборка PDF и лист «Поделиться» (там «Напечатать» и «Сохранить в Файлы»).
  Future<void> _print() async {
    if (_printing) return;
    final FlossCubit cubit = context.read<FlossCubit>();
    setState(() => _printing = true);
    try {
      await runPrintFlow(
        context,
        loadOptions: cubit.loadPrintOptions,
        summary: () async => (await cubit.printSummary()).valueOrNull,
        build: cubit.exportPdf,
        fileSharer: widget.fileSharer,
        originKey: _printKey,
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  ShareOrigin? _shareOrigin() {
    final RenderObject? box = _shareKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final Offset topLeft = box.localToGlobal(Offset.zero);
    return ShareOrigin(left: topLeft.dx, top: topLeft.dy, width: box.size.width, height: box.size.height);
  }

  Future<void> _share(FlossState state) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FlossFormat format = _formatOf(l10n, state);
    final result = await widget.sharer.shareText(
      format.shareText(state.projectName),
      subject: l10n.flossShareHeader(state.projectName),
      origin: _shareOrigin(),
    );
    if (!mounted || result.isSuccess) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.actionFailedTitle),
        content: Text(l10n.shareFailed),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }

  static FlossFormat _formatOf(AppLocalizations l10n, FlossState state) => FlossFormat(
    l10n,
    state.estimate!,
    withReserve: state.withReserve,
    shortage: state.shortage,
    hasStock: state.stock.isNotEmpty,
  );

  Future<void> _editStock(BuildContext context, FlossShortageLine line, FlossFormat format) async {
    final FlossCubit cubit = context.read<FlossCubit>();
    final double? value = await showCupertinoSheet<double>(
      context: context,
      builder: (sheetContext) => _StockSheet(line: line, format: format),
    );
    if (value != null) await cubit.setStock(line.purchase.ref, value);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return CupertinoPageScaffold(
      child: BlocConsumer<FlossCubit, FlossState>(
        listenWhen: (before, after) => after.writeFailure != null && after.writeFailure != before.writeFailure,
        listener: (context, state) => unawaited(
          showCupertinoDialog<void>(
            context: context,
            builder: (dialogContext) => CupertinoAlertDialog(
              title: Text(l10n.actionFailedTitle),
              content: Text(l10n.flossStockWriteFailed),
              actions: <Widget>[
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          ),
        ),
        builder: (context, state) {
          final double width = MediaQuery.sizeOf(context).width;
          final double side = math.max(tokens.spacing.l, (width - FlossScreen.maxContentWidth) / 2);
          final EdgeInsets inset = EdgeInsets.symmetric(horizontal: side);
          final bool canShare = state.status == FlossStatus.ready && !state.isEmpty;
          return Stack(
            children: <Widget>[
              CustomScrollView(
                slivers: <Widget>[
                  CupertinoSliverNavigationBar(largeTitle: Text(l10n.flossTitle)),
                  ..._body(context, state, inset),
                  SliverToBoxAdapter(child: SizedBox(height: 112 + MediaQuery.textScalerOf(context).scale(17) - 17)),
                ],
              ),
              if (canShare)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: tokens.spacing.l,
                  child: SafeArea(
                    child: Center(
                      child: GlassButton(
                        key: _shareKey,
                        semanticLabel: l10n.materialsShare,
                        onPressed: () => _share(state),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(AppIcons.share),
                              SizedBox(width: tokens.spacing.s),
                              Flexible(child: Text(l10n.materialsShare, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body(BuildContext context, FlossState state, EdgeInsets inset) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    Widget message(String title, {String? text, VoidCallback? onRetry}) => SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(title, textAlign: TextAlign.center, style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
            if (text != null) ...<Widget>[
              SizedBox(height: tokens.spacing.s),
              Text(
                text,
                textAlign: TextAlign.center,
                style: base.copyWith(color: secondary),
              ),
            ],
            if (onRetry != null) CupertinoButton(onPressed: onRetry, child: Text(l10n.libraryRetry)),
          ],
        ),
      ),
    );

    SliverPadding section(Widget child, {double top = 0}) => SliverPadding(
      padding: inset.copyWith(top: top),
      sliver: SliverToBoxAdapter(child: child),
    );

    Widget heading(String text) => Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m),
      child: Text(
        text,
        style: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: secondary),
      ),
    );

    switch (state.status) {
      case FlossStatus.loading:
        return const <Widget>[
          SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator())),
        ];
      case FlossStatus.failure:
        final Failure? failure = state.failure;
        return <Widget>[
          message(
            l10n.materialsLoadFailedTitle,
            text: failure is ValidationFailure ? l10n.flossUnsupported : failureMessage(l10n, failure!),
            onRetry: failure is ValidationFailure ? null : context.read<FlossCubit>().load,
          ),
        ];
      case FlossStatus.ready:
        final FlossFormat format = _formatOf(l10n, state);
        if (state.isEmpty) {
          if (!state.remainingOnly) {
            return <Widget>[message(l10n.flossEmptyTitle, text: l10n.flossEmptyMessage)];
          }
          return <Widget>[
            section(
              _Header(state: state, format: format),
              top: tokens.spacing.s,
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      l10n.flossRemainingDone,
                      textAlign: TextAlign.center,
                      style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                    ),
                    SizedBox(height: tokens.spacing.s),
                    Text(
                      l10n.flossRemainingDoneMessage,
                      textAlign: TextAlign.center,
                      style: base.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
            ),
          ];
        }
        final FlossEstimate estimate = state.estimate!;
        final FlossShortage shortage = state.shortage!;
        return <Widget>[
          section(
            _Header(state: state, format: format),
            top: tokens.spacing.s,
          ),
          section(
            AppListSection(
              margin: EdgeInsets.zero,
              footer: Text(l10n.flossPrintHint, style: base.copyWith(fontSize: 13, color: secondary)),
              children: <Widget>[
                CupertinoListTile.notched(
                  key: _printKey,
                  title: Text(l10n.flossPrint),
                  leading: const Icon(AppIcons.print),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => unawaited(_print()),
                ),
              ],
            ),
            top: tokens.spacing.m,
          ),
          section(heading(l10n.flossShoppingTitle), top: tokens.spacing.l),
          section(
            _ShortageSummary(shortage: shortage, remaining: state.remainingOnly, format: format),
            top: tokens.spacing.s,
          ),
          SliverPadding(
            padding: inset.copyWith(top: tokens.spacing.s),
            sliver: SliverList.separated(
              itemCount: estimate.purchases.length,
              separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.s),
              itemBuilder: (context, index) => _PurchaseRow(
                line: estimate.purchases[index],
                shortage: shortage.lines[index],
                format: format,
                onEdit: () => unawaited(_editStock(context, shortage.lines[index], format)),
              ),
            ),
          ),
          section(_TotalRow(format: format), top: tokens.spacing.m),
          if (estimate.beads.isNotEmpty) ...<Widget>[
            section(heading(l10n.flossBeadsTitle), top: tokens.spacing.l),
            SliverPadding(
              padding: inset.copyWith(top: tokens.spacing.s),
              sliver: SliverList.separated(
                itemCount: estimate.beads.length,
                separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.s),
                itemBuilder: (context, index) => _BeadRow(line: estimate.beads[index], format: format),
              ),
            ),
          ],
          section(heading(l10n.flossColorsTitle), top: tokens.spacing.l),
          SliverPadding(
            padding: inset.copyWith(top: tokens.spacing.s),
            sliver: SliverList.separated(
              itemCount: estimate.lines.length,
              separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.s),
              itemBuilder: (context, index) => _ColorRow(line: estimate.lines[index], format: format),
            ),
          ),
          if (estimate.lines.any((l) => l.isBlend))
            section(
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m),
                child: Text(l10n.flossBlendHint, style: base.copyWith(fontSize: 13, color: secondary)),
              ),
              top: tokens.spacing.s,
            ),
        ];
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.format});

  final FlossState state;
  final FlossFormat format;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          state.projectName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        Text(l10n.flossFabricLine(format.fabricLabel), style: base.copyWith(fontSize: 15, color: secondary)),
        Text(format.fabricNeedText, style: base.copyWith(fontSize: 15, color: secondary)),
        SizedBox(height: tokens.spacing.m),
        CupertinoSlidingSegmentedControl<bool>(
          groupValue: state.remainingOnly,
          onValueChanged: (value) => unawaited(context.read<FlossCubit>().setRemainingOnly(value: value ?? false)),
          children: <bool, Widget>{
            false: Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.s),
              child: Text(l10n.flossScopeAll),
            ),
            true: Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.s),
              child: Text(l10n.flossScopeRemaining),
            ),
          },
        ),
        if (state.remainingOnly)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.s),
            child: Text(l10n.flossScopeRemainingHint, style: base.copyWith(fontSize: 13, color: secondary)),
          ),
        SizedBox(height: tokens.spacing.m),
        if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
          MergeSemantics(
            child: Row(
              children: <Widget>[
                Expanded(child: Text(l10n.materialsReserveWith(format.reservePercent), style: base)),
                CupertinoSwitch(
                  value: state.withReserve,
                  onChanged: (value) => context.read<FlossCubit>().setWithReserve(value: value),
                ),
              ],
            ),
          )
        else
          CupertinoSlidingSegmentedControl<bool>(
            groupValue: state.withReserve,
            onValueChanged: (value) => context.read<FlossCubit>().setWithReserve(value: value ?? false),
            children: <bool, Widget>{
              false: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.s),
                child: Text(l10n.materialsReserveNone),
              ),
              true: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.s),
                child: Text(l10n.materialsReserveWith(format.reservePercent)),
              ),
            },
          ),
      ],
    );
  }
}

/// Непрозрачная карточка строки списка.
class _Card extends StatelessWidget {
  const _Card({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(tokens.radius.m),
        ),
        child: Padding(padding: EdgeInsets.all(tokens.spacing.m), child: child),
      ),
    );
  }
}

class _BeadRow extends StatelessWidget {
  const _BeadRow({required this.line, required this.format});

  final BeadPurchaseLine line;
  final FlossFormat format;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final String article = line.ref.toString();
    final String pieces = l10n.flossBeadPieces(format.beadPieces(line));
    return _Card(
      label: '$article, $pieces',
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              article,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            pieces,
            style: base.merge(context.tokens.counterTextStyle).copyWith(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({required this.line, required this.shortage, required this.format, required this.onEdit});

  final FlossPurchaseLine line;
  final FlossShortageLine shortage;
  final FlossFormat format;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final String skeins = format.skeinsText(format.purchaseSkeins(line));
    final String article = line.ref.toString();
    final String needHave = l10n.flossStockNeedHave(
      format.amountText(shortage.needSkeins),
      format.amountText(shortage.haveSkeins),
    );
    final String status = shortage.isCovered
        ? l10n.flossStockEnough
        : l10n.flossStockBuy(format.skeinsText(shortage.toBuy));
    final Color statusColor = shortage.isCovered
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.systemOrange.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: Semantics(
        button: true,
        hint: l10n.flossStockEdit,
        container: true,
        excludeSemantics: true,
        label: '$article, ${line.name ?? ''}, $skeins, $needHave, $status',
        onTap: onEdit,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(tokens.radius.m),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.m),
            child: Row(
              children: <Widget>[
                ColorSwatchView(rgb: line.rgb, size: 36),
                SizedBox(width: tokens.spacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        article,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      if (line.name != null)
                        Text(
                          line.name!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: base.copyWith(fontSize: 13, color: secondary),
                        ),
                      Text(
                        needHave,
                        style: base.merge(tokens.counterTextStyle).copyWith(fontSize: 13, color: secondary),
                      ),
                      Text(
                        status,
                        style: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: tokens.spacing.m),
                Text(
                  skeins,
                  style: base.merge(tokens.counterTextStyle).copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Итог сверки с запасом: хватает или сколько докупить.
class _ShortageSummary extends StatelessWidget {
  const _ShortageSummary({required this.shortage, required this.remaining, required this.format});

  final FlossShortage shortage;
  final bool remaining;
  final FlossFormat format;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final bool covered = shortage.isCovered;
    final String title = covered
        ? (remaining ? l10n.flossStockCoveredRemaining : l10n.flossStockCovered)
        : l10n.flossStockShort(format.skeinsText(shortage.totalToBuy));
    final Color color = covered
        ? CupertinoColors.systemGreen.resolveFrom(context)
        : CupertinoColors.systemOrange.resolveFrom(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600, color: color),
            ),
            if (!covered)
              Text(
                l10n.flossStockShortThreads(shortage.missingCount),
                style: base.copyWith(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Лист правки запаса нитки: сколько мотков осталось, шаг в полмотка.
class _StockSheet extends StatefulWidget {
  const _StockSheet({required this.line, required this.format});

  final FlossShortageLine line;
  final FlossFormat format;

  @override
  State<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends State<_StockSheet> {
  late double _value = widget.line.haveSkeins;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: Text(l10n.flossStockSheetTitle(widget.line.purchase.ref.toString())),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(tokens.minTapTarget),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        trailing: CupertinoButton(
          key: const ValueKey<String>('stock-save'),
          padding: EdgeInsets.zero,
          minimumSize: Size.square(tokens.minTapTarget),
          onPressed: () => Navigator.of(context).pop(_value),
          child: Text(l10n.commonSave),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: <Widget>[
            AppListSection(
              footer: Text(l10n.flossStockSheetHint, style: base.copyWith(fontSize: 13, color: secondary)),
              children: <Widget>[
                CupertinoListTile(
                  title: StockStepper(value: _value, onChanged: (v) => setState(() => _value = v)),
                ),
              ],
            ),
            if (widget.line.haveSkeins > 0)
              AppListSection(
                children: <Widget>[
                  CupertinoListTile(
                    key: const ValueKey<String>('stock-clear'),
                    title: Center(
                      child: Text(
                        l10n.flossStockClear,
                        style: TextStyle(color: CupertinoColors.destructiveRed.resolveFrom(context)),
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(0.0),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.line, required this.format});

  final FlossMaterialLine line;
  final FlossFormat format;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final String article = format.articleLabel(line.color);
    final String stitches = l10n.flossStitches(format.count(line.crossStitches));
    final String? extras = format.extrasText(line);
    final String skeins = format.skeinsText(format.skeins(line));
    return _Card(
      label: '$article, ${line.color.name}, $stitches, ${extras ?? ''}, $skeins',
      child: Row(
        children: <Widget>[
          ColorSwatchView(rgb: line.color.rgb, size: 36),
          if (line.color.symbol != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 28),
              child: Text(line.color.symbol!, textAlign: TextAlign.center, style: base.copyWith(fontSize: 17)),
            ),
          SizedBox(width: tokens.spacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  article,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  line.color.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: base.copyWith(fontSize: 13, color: secondary),
                ),
                Text(
                  extras == null ? stitches : '$stitches, $extras',
                  style: base.merge(tokens.counterTextStyle).copyWith(fontSize: 13, color: secondary),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.m),
          Text(skeins, style: base.merge(tokens.counterTextStyle).copyWith(fontSize: 15)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.format});

  final FlossFormat format;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final String skeins = format.skeinsText(format.totalSkeins);
    return Semantics(
      container: true,
      label: '${l10n.materialsTotal}: $skeins',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: tokens.spacing.m,
              children: <Widget>[
                Text(l10n.materialsTotal, style: base.copyWith(fontSize: 17, fontWeight: FontWeight.w700)),
                Text(
                  skeins,
                  style: base.merge(tokens.counterTextStyle).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: tokens.spacing.s),
            Text(
              l10n.flossEstimateHint,
              style: base.copyWith(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
            ),
          ],
        ),
      ),
    );
  }
}
