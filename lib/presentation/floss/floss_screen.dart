import 'dart:math' as math;

import 'package:beading/core/failure.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:beading/presentation/floss/floss_cubit.dart';
import 'package:beading/presentation/floss/floss_format.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:beading/presentation/widgets/glass/glass_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Расход мулине для вышивки: канва, список покупок по ниткам, таблица по цветам схемы и «Поделиться».
/// Ждёт [FlossCubit] в дереве выше.
class FlossScreen extends StatefulWidget {
  const FlossScreen({required this.sharer, super.key});

  static const String routePath = '/projects/:projectId/floss';

  static String locationFor(String projectId) => '/projects/$projectId/floss';

  static const double maxContentWidth = 720;

  final TextSharer sharer;

  @override
  State<FlossScreen> createState() => _FlossScreenState();
}

class _FlossScreenState extends State<FlossScreen> {
  final GlobalKey _shareKey = GlobalKey();

  ShareOrigin? _shareOrigin() {
    final RenderObject? box = _shareKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final Offset topLeft = box.localToGlobal(Offset.zero);
    return ShareOrigin(left: topLeft.dx, top: topLeft.dy, width: box.size.width, height: box.size.height);
  }

  Future<void> _share(FlossState state) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FlossFormat format = FlossFormat(l10n, state.estimate!, withReserve: state.withReserve);
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return CupertinoPageScaffold(
      child: BlocBuilder<FlossCubit, FlossState>(
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
        if (state.isEmpty) {
          return <Widget>[message(l10n.flossEmptyTitle, text: l10n.flossEmptyMessage)];
        }
        final FlossFormat format = FlossFormat(l10n, state.estimate!, withReserve: state.withReserve);
        final FlossEstimate estimate = state.estimate!;
        return <Widget>[
          section(
            _Header(state: state, format: format),
            top: tokens.spacing.s,
          ),
          section(heading(l10n.flossShoppingTitle), top: tokens.spacing.l),
          SliverPadding(
            padding: inset.copyWith(top: tokens.spacing.s),
            sliver: SliverList.separated(
              itemCount: estimate.purchases.length,
              separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.s),
              itemBuilder: (context, index) => _PurchaseRow(line: estimate.purchases[index], format: format),
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
  const _PurchaseRow({required this.line, required this.format});

  final FlossPurchaseLine line;
  final FlossFormat format;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final String skeins = format.skeinsText(format.purchaseSkeins(line));
    final String article = line.ref.toString();
    return _Card(
      label: '$article, ${line.name ?? ''}, $skeins',
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
