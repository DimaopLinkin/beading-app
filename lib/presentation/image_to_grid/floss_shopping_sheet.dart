import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/presentation/floss/floss_format.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:flutter/cupertino.dart';

/// Лист «Что купить» в мастере: нитки и канва по посчитанной схеме, ещё до сохранения.
Future<void> showFlossShoppingSheet(BuildContext context, FlossEstimate estimate) => showCupertinoSheet<void>(
  context: context,
  builder: (sheetContext) => _FlossShoppingSheet(estimate: estimate),
);

class _FlossShoppingSheet extends StatelessWidget {
  const _FlossShoppingSheet({required this.estimate});

  final FlossEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final FlossFormat format = FlossFormat(l10n, estimate, withReserve: false);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: Text(l10n.flossShoppingTitle),
        trailing: CupertinoButton(
          key: const ValueKey<String>('shopping-close'),
          padding: EdgeInsets.zero,
          minimumSize: Size.square(tokens.minTapTarget),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonOk),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.spacing.l),
          children: <Widget>[
            Text(format.fabricLabel, style: base.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: tokens.spacing.xs),
            Text(format.fabricNeedText, style: base.copyWith(fontSize: 13, color: secondary)),
            SizedBox(height: tokens.spacing.l),
            for (final FlossPurchaseLine line in estimate.purchases) ...<Widget>[
              Row(
                children: <Widget>[
                  ColorSwatchView(rgb: line.rgb),
                  SizedBox(width: tokens.spacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(line.ref.toString(), style: base.copyWith(fontWeight: FontWeight.w600)),
                        if (line.name != null) Text(line.name!, style: base.copyWith(fontSize: 13, color: secondary)),
                      ],
                    ),
                  ),
                  Text(format.skeinsText(format.purchaseSkeins(line))),
                ],
              ),
              SizedBox(height: tokens.spacing.m),
            ],
            Text(
              l10n.flossTotal(format.skeinsText(format.totalSkeins)),
              style: base.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: tokens.spacing.s),
            Text(l10n.flossEstimateHint, style: base.copyWith(fontSize: 13, color: secondary)),
          ],
        ),
      ),
    );
  }
}
