import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/min_tap_target.dart';
import 'package:flutter/cupertino.dart';

/// Чип выбора в горизонтальной ленте (фильтры, вкладки брендов). Нажатие выбирает, область не меньше 44 pt.
class PillChip extends StatelessWidget {
  const PillChip({required this.label, required this.selected, required this.onTap, super.key});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final Color fill = selected
        ? CupertinoTheme.of(context).primaryColor
        : CupertinoColors.tertiarySystemFill.resolveFrom(context);
    final Color text = selected ? CupertinoColors.white : CupertinoColors.label.resolveFrom(context);
    return Padding(
      padding: EdgeInsets.only(right: tokens.spacing.s),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: MinTapTarget(
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(tokens.radius.xl)),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l, vertical: tokens.spacing.s),
                child: Text(
                  label,
                  style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(color: text, fontSize: 15),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
