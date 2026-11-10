import 'dart:math' as math;

import 'package:beading/core/failure.dart';
import 'package:beading/domain/materials/bead_estimate.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/materials/materials_cubit.dart';
import 'package:beading/presentation/materials/materials_format.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:beading/presentation/widgets/glass/glass_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Материалы проекта: таблица цветов схемы (образец, символ, артикул, название, бусины, вес), итог и кнопка
/// «Поделиться списком». Ждёт [MaterialsCubit] в дереве выше.
class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({required this.sharer, super.key});

  static const String routePath = '/projects/:projectId/materials';

  static String locationFor(String projectId) => '/projects/$projectId/materials';

  static const double maxContentWidth = 720;

  final TextSharer sharer;

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  final GlobalKey _shareKey = GlobalKey();

  /// Прямоугольник кнопки в координатах окна: от него лист «Поделиться» открывается на iPad и macOS.
  ShareOrigin? _shareOrigin() {
    final RenderObject? box = _shareKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final Offset topLeft = box.localToGlobal(Offset.zero);
    return ShareOrigin(left: topLeft.dx, top: topLeft.dy, width: box.size.width, height: box.size.height);
  }

  Future<void> _share(MaterialsState state) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MaterialsFormat format = MaterialsFormat(l10n, state.estimate!, withReserve: state.withReserve);
    final result = await widget.sharer.shareText(
      format.shareText(state.projectName),
      subject: l10n.materialsShareSubject(state.projectName),
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
      child: BlocBuilder<MaterialsCubit, MaterialsState>(
        builder: (context, state) {
          final double width = MediaQuery.sizeOf(context).width;
          final double side = math.max(tokens.spacing.l, (width - MaterialsScreen.maxContentWidth) / 2);
          final EdgeInsets inset = EdgeInsets.symmetric(horizontal: side);
          final bool canShare = state.status == MaterialsStatus.ready && !state.isEmpty;
          return Stack(
            children: <Widget>[
              CustomScrollView(
                slivers: <Widget>[
                  CupertinoSliverNavigationBar(largeTitle: Text(l10n.materialsTitle)),
                  ..._body(context, state, inset),
                  // Место под плавающую кнопку.
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

  List<Widget> _body(BuildContext context, MaterialsState state, EdgeInsets inset) {
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
      case MaterialsStatus.loading:
        return const <Widget>[
          SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator())),
        ];
      case MaterialsStatus.failure:
        final Failure? failure = state.failure;
        return <Widget>[
          message(
            l10n.materialsLoadFailedTitle,
            text: failure is ValidationFailure ? l10n.materialsUnsupported : failureMessage(l10n, failure!),
            onRetry: failure is ValidationFailure ? null : context.read<MaterialsCubit>().load,
          ),
        ];
      case MaterialsStatus.ready:
        if (state.isEmpty) {
          return <Widget>[message(l10n.materialsEmptyTitle, text: l10n.materialsEmptyMessage)];
        }
        final MaterialsFormat format = MaterialsFormat(l10n, state.estimate!, withReserve: state.withReserve);
        return <Widget>[
          SliverPadding(
            padding: inset.copyWith(top: tokens.spacing.s),
            sliver: SliverToBoxAdapter(
              child: _ReserveSwitch(state: state, format: format),
            ),
          ),
          SliverPadding(
            padding: inset.copyWith(top: tokens.spacing.m),
            sliver: SliverList.separated(
              itemCount: state.estimate!.lines.length,
              separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.s),
              itemBuilder: (context, index) => _MaterialRow(line: state.estimate!.lines[index], format: format),
            ),
          ),
          SliverPadding(
            padding: inset.copyWith(top: tokens.spacing.m),
            sliver: SliverToBoxAdapter(child: _TotalRow(format: format)),
          ),
        ];
    }
  }
}

class _ReserveSwitch extends StatelessWidget {
  const _ReserveSwitch({required this.state, required this.format});

  final MaterialsState state;
  final MaterialsFormat format;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          state.projectName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        Text(
          l10n.materialsBeadSize(format.beadSizeLabel),
          style: base.copyWith(fontSize: 15, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
        ),
        SizedBox(height: tokens.spacing.m),
        if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
          // Крупный шрифт: подписи сегментов не помещаются, вместо них выключатель.
          MergeSemantics(
            child: Row(
              children: <Widget>[
                Expanded(child: Text(l10n.materialsReserveWith(format.reservePercent), style: base)),
                CupertinoSwitch(
                  value: state.withReserve,
                  onChanged: (value) => context.read<MaterialsCubit>().setWithReserve(value: value),
                ),
              ],
            ),
          )
        else
          CupertinoSlidingSegmentedControl<bool>(
            groupValue: state.withReserve,
            onValueChanged: (value) => context.read<MaterialsCubit>().setWithReserve(value: value ?? false),
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

/// Строка таблицы: образец, символ, артикул и название, количество и вес. Непрозрачная.
class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.line, required this.format});

  final BeadMaterialLine line;
  final MaterialsFormat format;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final String article = format.articleLabel(line.color);
    final String pieces = format.piecesText(format.pieces(line));
    final String grams = format.gramsText(format.grams(line));
    final bool large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final TextStyle piecesStyle = base
        .merge(tokens.counterTextStyle)
        .copyWith(fontSize: 17, fontWeight: FontWeight.w600);
    final TextStyle gramsStyle = base.merge(tokens.counterTextStyle).copyWith(fontSize: 13, color: secondary);
    final List<Widget> identity = <Widget>[
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
          ],
        ),
      ),
    ];
    return Semantics(
      container: true,
      label: '$article, ${line.color.name}, $pieces, $grams',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(tokens.radius.m),
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.m),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(children: identity),
                    SizedBox(height: tokens.spacing.s),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: tokens.spacing.m,
                      children: <Widget>[
                        Text(pieces, style: piecesStyle),
                        Text(grams, style: gramsStyle),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: <Widget>[
                    ...identity,
                    SizedBox(width: tokens.spacing.m),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(pieces, style: piecesStyle),
                        Text(grams, style: gramsStyle),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.format});

  final MaterialsFormat format;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final String pieces = format.piecesText(format.totalPieces);
    final String grams = format.gramsText(format.totalGrams);
    return Semantics(
      container: true,
      label: '${l10n.materialsTotal}: $pieces, $grams',
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
                  pieces,
                  style: base.merge(tokens.counterTextStyle).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                Text(grams, style: base.merge(tokens.counterTextStyle).copyWith(fontSize: 17)),
              ],
            ),
            SizedBox(height: tokens.spacing.s),
            Text(
              l10n.materialsWeightHint,
              style: base.copyWith(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
            ),
          ],
        ),
      ),
    );
  }
}
