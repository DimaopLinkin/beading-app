import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_filter.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/min_tap_target.dart';
import 'package:flutter/cupertino.dart';

/// Чипы фильтров: ремесло и статус. Нажатие выбирает значение, повторное снимает.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    required this.filter,
    required this.onCraft,
    required this.onStatus,
    this.horizontalPadding = 16,
    super.key,
  });

  final ProjectFilter filter;
  final ValueChanged<Craft> onCraft;
  final ValueChanged<ProjectStatus> onStatus;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: <Widget>[
          for (final Craft craft in Craft.values)
            _Chip(label: craft.label(l10n), selected: filter.craft == craft, onTap: () => onCraft(craft)),
          SizedBox(width: tokens.spacing.m),
          for (final ProjectStatus status in ProjectStatus.values)
            _Chip(label: status.label(l10n), selected: filter.status == status, onTap: () => onStatus(status)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

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
