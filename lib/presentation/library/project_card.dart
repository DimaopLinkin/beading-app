import 'package:beading/domain/projects/project.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/library/project_thumbnail_provider.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Карточка проекта в списке. Непрозрачная: стекло только на слое управления.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    required this.project,
    required this.thumbnails,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  static const double thumbnailSize = 64;

  final Project project;
  final ProjectThumbnailRegistry thumbnails;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color background = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final ProjectThumbnailProvider? provider = thumbnails.providerFor(project);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      child: Semantics(
        button: true,
        container: true,
        child: DecoratedBox(
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(tokens.radius.m)),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.m),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radius.s),
                  child: SizedBox.square(
                    dimension: thumbnailSize,
                    child: provider != null
                        ? provider.build(context, project)
                        : ColoredBox(
                            color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                            child: Icon(project.craft.icon, color: secondary),
                          ),
                  ),
                ),
                SizedBox(width: tokens.spacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        project.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: base.copyWith(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: tokens.spacing.xs),
                      Text(
                        l10n.libraryCardSubtitle(project.craft.label(l10n), project.technique.label(l10n)),
                        style: base.copyWith(fontSize: 14, color: secondary),
                      ),
                      Text(
                        l10n.libraryCardLastWorked(project.status.label(l10n), project.lastWorkedAt.toLocal()),
                        style: base.copyWith(fontSize: 13, color: secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
