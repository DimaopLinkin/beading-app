import 'package:beading/domain/projects/load_project_preview.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/grid_thumbnail.dart';
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
    this.loadPreview,
    super.key,
  });

  static const double thumbnailSize = 64;

  final Project project;
  final ProjectThumbnailRegistry thumbnails;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  /// Картинка и процент готовности; без него карточка показывает только значок ремесла.
  final LoadProjectPreview? loadPreview;

  @override
  Widget build(BuildContext context) {
    final ProjectThumbnailProvider? provider = thumbnails.providerFor(project);
    return _PreviewBuilder(
      // Готовность и картинка читаются заново, когда над проектом поработали (меняется lastWorkedAt).
      key: ValueKey<String>('${project.id}-${project.lastWorkedAt.microsecondsSinceEpoch}'),
      project: project,
      loader: provider == null ? loadPreview : null,
      builder: (context, preview) => _card(context, provider, preview),
    );
  }

  Widget _card(BuildContext context, ProjectThumbnailProvider? provider, ProjectPreview? preview) {
    final AppTokensData tokens = context.tokens;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color background = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final int? percent = preview?.percent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      child: Semantics(
        button: onTap != null,
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
                    child: provider != null ? provider.build(context, project) : _picture(context, preview, secondary),
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
                      if (percent != null) ...<Widget>[
                        SizedBox(height: tokens.spacing.xs),
                        _ProgressLine(
                          key: const ValueKey<String>('project-progress'),
                          fraction: preview!.progress!,
                          label: l10n.libraryCardProgress(percent),
                        ),
                      ],
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

  Widget _picture(BuildContext context, ProjectPreview? preview, Color secondary) {
    final pattern = preview?.pattern;
    if (pattern != null) {
      return GridThumbnail(pattern: pattern);
    }
    final cover = preview?.cover;
    if (cover != null) {
      return Image.memory(
        cover,
        fit: BoxFit.cover,
        cacheWidth: (thumbnailSize * 3).toInt(),
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _icon(context, secondary),
      );
    }
    return _icon(context, secondary);
  }

  Widget _icon(BuildContext context, Color secondary) => ColoredBox(
    color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
    child: Icon(project.craft.icon, color: secondary),
  );
}

/// Загружает превью один раз на карточку; пока оно читается, строит карточку без него.
class _PreviewBuilder extends StatefulWidget {
  const _PreviewBuilder({required this.project, required this.loader, required this.builder, super.key});

  final Project project;
  final LoadProjectPreview? loader;
  final Widget Function(BuildContext context, ProjectPreview? preview) builder;

  @override
  State<_PreviewBuilder> createState() => _PreviewBuilderState();
}

class _PreviewBuilderState extends State<_PreviewBuilder> {
  ProjectPreview? _preview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final LoadProjectPreview? loader = widget.loader;
    if (loader != null) {
      loader(widget.project).then((preview) {
        if (mounted) {
          setState(() => _preview = preview);
        }
      });
    }
  }

  @override
  void didUpdateWidget(_PreviewBuilder old) {
    super.didUpdateWidget(old);
    if (old.project != widget.project || old.loader != widget.loader) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _preview);
}

/// Тонкая полоса прогресса с процентом справа.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.fraction, required this.label, super.key});

  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final Color accent = tokens.accent.resolveFrom(context);
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: <Widget>[
                      ColoredBox(
                        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                        child: const SizedBox.expand(),
                      ),
                      FractionallySizedBox(
                        widthFactor: fraction.clamp(0, 1),
                        child: ColoredBox(color: accent, child: const SizedBox.expand()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.s),
            Text(
              label,
              style: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
