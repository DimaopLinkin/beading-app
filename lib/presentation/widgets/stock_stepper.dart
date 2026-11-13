import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// В чём считают запас.
enum StockUnit {
  /// Мотки мулине: шаг — полмотка.
  skeins(step: 0.5, max: 999),

  /// Граммы бисера: шаг — 5 г, примерно пробирка.
  grams(step: 5, max: 9999)
  ;

  const StockUnit({required this.step, required this.max});

  final double step;
  final double max;
}

/// Число мотков или граммов с кнопками «меньше» и «больше»: шаг и предел по [unit], от нуля.
class StockStepper extends StatelessWidget {
  const StockStepper({required this.value, required this.onChanged, this.unit = StockUnit.skeins, super.key});

  final double value;
  final ValueChanged<double> onChanged;
  final StockUnit unit;

  double get step => unit.step;
  double get max => unit.max;

  static final NumberFormat _amounts = NumberFormat('#,##0.#', 'ru');

  /// «1,5 мот.» или «15 г».
  static String amountText(AppLocalizations l10n, double amount, {StockUnit unit = StockUnit.skeins}) => switch (unit) {
    StockUnit.skeins => l10n.flossStockAmount(_amounts.format(amount)),
    StockUnit.grams => l10n.beadStockAmount(_amounts.format(amount)),
  };

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
            amountText(l10n, value, unit: unit),
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
