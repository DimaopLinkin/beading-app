import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// Число мотков с кнопками «меньше» и «больше»: шаг — полмотка, от нуля до [max].
class StockStepper extends StatelessWidget {
  const StockStepper({required this.value, required this.onChanged, this.max = 999, super.key});

  final double value;
  final ValueChanged<double> onChanged;
  final double max;

  static const double step = 0.5;

  static final NumberFormat _amounts = NumberFormat('#,##0.#', 'ru');

  /// «1,5 мот.».
  static String amountText(AppLocalizations l10n, double skeins) => l10n.flossStockAmount(_amounts.format(skeins));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CupertinoButton(
          key: const ValueKey<String>('stock-less'),
          minimumSize: Size.square(tokens.minTapTarget),
          onPressed: value <= 0 ? null : () => onChanged((value - step).clamp(0, max).toDouble()),
          child: Semantics(label: l10n.flossStockLess, child: const Icon(CupertinoIcons.minus_circle, size: 32)),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 96),
          child: Text(
            amountText(l10n, value),
            key: const ValueKey<String>('stock-value'),
            textAlign: TextAlign.center,
            style: base.merge(tokens.counterTextStyle).copyWith(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        CupertinoButton(
          key: const ValueKey<String>('stock-more'),
          minimumSize: Size.square(tokens.minTapTarget),
          onPressed: value >= max ? null : () => onChanged((value + step).clamp(0, max).toDouble()),
          child: Semantics(label: l10n.flossStockMore, child: const Icon(CupertinoIcons.plus_circle, size: 32)),
        ),
      ],
    );
  }
}
