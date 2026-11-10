import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_filter.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/pill_chip.dart';
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
            PillChip(label: craft.label(l10n), selected: filter.craft == craft, onTap: () => onCraft(craft)),
          SizedBox(width: tokens.spacing.m),
          for (final ProjectStatus status in ProjectStatus.values)
            PillChip(label: status.label(l10n), selected: filter.status == status, onTap: () => onStatus(status)),
        ],
      ),
    );
  }
}
