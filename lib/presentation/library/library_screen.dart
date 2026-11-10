import 'dart:math' as math;

import 'package:beading/domain/projects/project.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/filter_chip_bar.dart';
import 'package:beading/presentation/library/library_cubit.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:beading/presentation/library/new_project_sheet.dart';
import 'package:beading/presentation/library/project_card.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/library/project_thumbnail_provider.dart';
import 'package:beading/presentation/library/swipe_action_row.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Главный экран «Мои работы»: поиск, фильтры, карточки проектов и кнопка «+».
///
/// Ждёт [LibraryCubit] в дереве выше. [onOpenProject] подключат экраны работы над проектом (T07 и дальше).
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.newProjects,
    required this.thumbnails,
    this.onOpenProject,
    this.onOpenSettings,
    super.key,
  });

  static const double maxContentWidth = 720;

  final NewProjectRegistry newProjects;
  final ProjectThumbnailRegistry thumbnails;
  final void Function(BuildContext context, Project project)? onOpenProject;

  /// Открывает настройки; `null` — кнопки нет.
  final VoidCallback? onOpenSettings;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(Project project) async {
    final LibraryCubit cubit = context.read<LibraryCubit>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.projectDeleteTitle(project.name)),
        content: Text(l10n.projectDeleteMessage),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.projectDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await cubit.delete(project.id);
    }
  }

  Future<void> _rename(Project project) async {
    final LibraryCubit cubit = context.read<LibraryCubit>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextEditingController controller = TextEditingController(text: project.name);
    final String? name = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.projectRenameTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: l10n.projectNamePlaceholder,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
        ),
        actions: <Widget>[
          CupertinoDialogAction(onPressed: () => Navigator.of(dialogContext).pop(), child: Text(l10n.cancel)),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) {
      await cubit.rename(project.id, name);
    }
  }

  Future<void> _showActions(Project project) async {
    final LibraryCubit cubit = context.read<LibraryCubit>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(project.name),
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop('rename'),
            child: Text(l10n.projectRename),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop('duplicate'),
            child: Text(l10n.projectDuplicate),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(sheetContext).pop('delete'),
            child: Text(l10n.projectDelete),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    switch (action) {
      case 'rename':
        await _rename(project);
      case 'duplicate':
        await cubit.duplicate(project.id);
      case 'delete':
        await _confirmDelete(project);
    }
  }

  Future<void> _showActionFailure(LibraryState state) async {
    final LibraryCubit cubit = context.read<LibraryCubit>();
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String message = failureMessage(l10n, state.actionFailure!);
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.actionFailedTitle),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
    cubit.acknowledgeActionFailure();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final LibraryCubit cubit = context.read<LibraryCubit>();

    return MultiBlocListener(
      listeners: <BlocListener<LibraryCubit, LibraryState>>[
        BlocListener<LibraryCubit, LibraryState>(
          listenWhen: (previous, current) => previous.actionFailure == null && current.actionFailure != null,
          listener: (context, state) => _showActionFailure(state),
        ),
        BlocListener<LibraryCubit, LibraryState>(
          listenWhen: (previous, current) => previous.filter.query != current.filter.query,
          listener: (context, state) {
            if (_search.text != state.filter.query) {
              _search.text = state.filter.query;
            }
          },
        ),
      ],
      child: CupertinoPageScaffold(
        child: BlocBuilder<LibraryCubit, LibraryState>(
          builder: (context, state) {
            final double width = MediaQuery.sizeOf(context).width;
            final double side = math.max(tokens.spacing.l, (width - LibraryScreen.maxContentWidth) / 2);
            final EdgeInsets inset = EdgeInsets.symmetric(horizontal: side);
            return Stack(
              children: <Widget>[
                CustomScrollView(
                  slivers: <Widget>[
                    CupertinoSliverNavigationBar(
                      largeTitle: Text(l10n.libraryTitle),
                      trailing: widget.onOpenSettings == null
                          ? null
                          : CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.square(tokens.minTapTarget),
                              onPressed: widget.onOpenSettings,
                              child: Semantics(label: l10n.settingsTitle, child: const Icon(AppIcons.settings)),
                            ),
                    ),
                    SliverPadding(
                      padding: inset.copyWith(top: tokens.spacing.s, bottom: tokens.spacing.s),
                      sliver: SliverToBoxAdapter(
                        child: CupertinoSearchTextField(
                          controller: _search,
                          placeholder: l10n.librarySearchPlaceholder,
                          onChanged: cubit.setQuery,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: FilterChipBar(
                        filter: state.filter,
                        horizontalPadding: side,
                        onCraft: cubit.toggleCraft,
                        onStatus: cubit.toggleStatus,
                      ),
                    ),
                    ..._body(context, state, inset),
                    // Место под плавающую кнопку «+».
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
                Positioned(
                  right: tokens.spacing.l,
                  bottom: tokens.spacing.l,
                  child: SafeArea(
                    child: GlassButton(
                      semanticLabel: l10n.libraryAddSemantic,
                      onPressed: () =>
                          showNewProjectSheet(context, widget.newProjects, initialCraft: state.filter.craft),
                      child: const Icon(AppIcons.add),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, LibraryState state, EdgeInsets inset) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final LibraryCubit cubit = context.read<LibraryCubit>();

    Widget message(String title, String text, {String? actionLabel, VoidCallback? onAction}) => SliverFillRemaining(
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
            SizedBox(height: tokens.spacing.s),
            Text(
              text,
              textAlign: TextAlign.center,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            if (actionLabel != null) CupertinoButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );

    switch (state.status) {
      case LibraryStatus.loading:
        return const <Widget>[
          SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator())),
        ];
      case LibraryStatus.failure:
        return <Widget>[
          message(
            l10n.libraryLoadFailedTitle,
            l10n.actionFailedGeneric,
            actionLabel: l10n.libraryRetry,
            onAction: cubit.retry,
          ),
        ];
      case LibraryStatus.ready:
        if (!state.hasProjects) {
          return <Widget>[message(l10n.libraryEmptyTitle, l10n.libraryEmptyMessage)];
        }
        if (state.hasNoMatches) {
          return <Widget>[
            message(
              l10n.libraryNoMatchesTitle,
              l10n.libraryNoMatchesMessage,
              actionLabel: l10n.libraryResetFilters,
              onAction: cubit.clearFilters,
            ),
          ];
        }
        final List<Project> projects = state.visible;
        return <Widget>[
          SliverPadding(
            padding: inset.copyWith(top: tokens.spacing.m),
            sliver: SliverList.separated(
              itemCount: projects.length,
              separatorBuilder: (_, _) => SizedBox(height: tokens.spacing.s),
              itemBuilder: (context, index) {
                final Project project = projects[index];
                return SwipeActionRow(
                  key: ValueKey<String>('project-${project.id}'),
                  actions: <SwipeAction>[
                    SwipeAction(
                      label: l10n.projectRename,
                      color: CupertinoColors.systemBlue.resolveFrom(context),
                      onPressed: () => _rename(project),
                    ),
                    SwipeAction(
                      label: l10n.projectDuplicate,
                      color: CupertinoColors.systemOrange.resolveFrom(context),
                      onPressed: () => cubit.duplicate(project.id),
                    ),
                    SwipeAction(
                      label: l10n.projectDelete,
                      color: CupertinoColors.systemRed.resolveFrom(context),
                      onPressed: () => _confirmDelete(project),
                    ),
                  ],
                  child: ProjectCard(
                    project: project,
                    thumbnails: widget.thumbnails,
                    onTap: widget.onOpenProject == null ? null : () => widget.onOpenProject!(context, project),
                    onLongPress: () => _showActions(project),
                  ),
                );
              },
            ),
          ),
        ];
    }
  }
}
