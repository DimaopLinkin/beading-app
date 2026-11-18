import 'package:beading/domain/steps/step_template.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/steps/new_steps_cubit.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/app_list_section.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Новая инструкция: название и три способа начать (пустая, из фото, шаблон). Закрывается с id проекта.
class NewStepsScreen extends StatefulWidget {
  const NewStepsScreen({super.key});

  static const String routePath = '/steps-new';

  @override
  State<NewStepsScreen> createState() => _NewStepsScreenState();
}

class _NewStepsScreenState extends State<NewStepsScreen> {
  late final TextEditingController _name = TextEditingController(
    text: AppLocalizations.of(context).stepsNewDefaultName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _title {
    final String t = _name.text.trim();
    return t.isEmpty ? AppLocalizations.of(context).stepsNewDefaultName : t;
  }

  Future<void> _photoMenu(BuildContext context, NewStepsCubit cubit) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? camera = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (popup) => CupertinoActionSheet(
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popup).pop(true),
            child: Text(l10n.stepsNewTakePhoto),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popup).pop(false),
            child: Text(l10n.stepsNewPickPhotos),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(popup).pop(), child: Text(l10n.cancel)),
      ),
    );
    if (camera != null) {
      await cubit.fromPhotos(_title, camera: camera);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final NewStepsCubit cubit = context.read<NewStepsCubit>();
    return BlocConsumer<NewStepsCubit, NewStepsState>(
      listenWhen: (a, b) => a.createdId != b.createdId && b.createdId != null,
      listener: (context, state) => Navigator.of(context).pop(state.createdId),
      builder: (context, state) => CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(l10n.stepsNewTitle)),
        child: SafeArea(
          child: ListView(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.all(tokens.spacing.l),
                child: CupertinoTextField(
                  key: const ValueKey<String>('steps-new-name'),
                  controller: _name,
                  placeholder: l10n.stepsNewName,
                  textInputAction: TextInputAction.done,
                  maxLength: 80,
                ),
              ),
              AppListSection(
                children: <Widget>[
                  CupertinoListTile(
                    key: const ValueKey<String>('steps-new-empty'),
                    leading: const Icon(AppIcons.add),
                    title: Text(l10n.stepsNewEmpty),
                    subtitle: Text(l10n.stepsNewEmptyHint),
                    trailing: const CupertinoListTileChevron(),
                    onTap: state.busy ? null : () => cubit.createEmpty(_title),
                  ),
                  CupertinoListTile(
                    key: const ValueKey<String>('steps-new-photos'),
                    leading: const Icon(AppIcons.photo),
                    title: Text(l10n.stepsNewFromPhotos),
                    subtitle: Text(l10n.stepsNewFromPhotosHint),
                    trailing: const CupertinoListTileChevron(),
                    onTap: state.busy ? null : () => _photoMenu(context, cubit),
                  ),
                ],
              ),
              if (state.templates.isNotEmpty)
                AppListSection(
                  header: Text(l10n.stepsNewTemplates),
                  children: <Widget>[
                    for (final StepTemplate t in state.templates)
                      CupertinoListTile(
                        key: ValueKey<String>('steps-new-template-${t.id}'),
                        leading: const Icon(AppIcons.template),
                        title: Text(t.title),
                        subtitle: t.description.isEmpty ? null : Text(t.description),
                        trailing: const CupertinoListTileChevron(),
                        onTap: state.busy ? null : () => cubit.fromTemplate(_title, t.id),
                      ),
                  ],
                ),
              if (state.busy)
                Padding(
                  padding: EdgeInsets.all(tokens.spacing.l),
                  child: const Center(child: CupertinoActivityIndicator()),
                ),
              if (state.problem != null)
                Padding(
                  padding: EdgeInsets.all(tokens.spacing.l),
                  child: Text(
                    state.problem == NewStepsProblem.photosFailed ? l10n.stepsNewPhotosFailed : l10n.stepsNewFailed,
                    key: const ValueKey<String>('steps-new-problem'),
                    style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
