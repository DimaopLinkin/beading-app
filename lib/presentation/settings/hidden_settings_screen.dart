import 'dart:async';

import 'package:beading/domain/settings/special_date.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/settings/settings_state.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Скрытый раздел: имя для комплиментов и особые даты. Открывается долгим нажатием на версию.
class HiddenSettingsScreen extends StatefulWidget {
  const HiddenSettingsScreen({super.key});

  @override
  State<HiddenSettingsScreen> createState() => _HiddenSettingsScreenState();
}

class _HiddenSettingsScreenState extends State<HiddenSettingsScreen> {
  late final SettingsCubit _cubit = context.read<SettingsCubit>();
  late final TextEditingController _name = TextEditingController(text: _cubit.state.userName);
  final FocusNode _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) unawaited(_commitName());
    });
  }

  @override
  void dispose() {
    // Имя, введённое без «Готово», тоже сохраняем: кубит живёт дольше экрана.
    unawaited(_cubit.setUserName(_name.text));
    _nameFocus.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _commitName() async {
    await _cubit.setUserName(_name.text);
    // Пустое имя превращается в имя по умолчанию: показываем его в поле.
    if (mounted && _name.text != _cubit.state.userName) _name.text = _cubit.state.userName;
  }

  Future<void> _addDate(SettingsCubit cubit) async {
    final SpecialDate? date = await showCupertinoModalPopup<SpecialDate>(
      context: context,
      builder: (_) => const _AddDateSheet(),
    );
    if (date != null) await cubit.addSpecialDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SettingsCubit cubit = context.read<SettingsCubit>();
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.hiddenTitle)),
      child: SafeArea(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) => ListView(
            children: <Widget>[
              CupertinoListSection.insetGrouped(
                header: Text(l10n.hiddenSectionName),
                children: <Widget>[
                  CupertinoTextFormFieldRow(
                    key: const ValueKey<String>('hidden-name'),
                    controller: _name,
                    focusNode: _nameFocus,
                    placeholder: l10n.hiddenNameHint,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: () {
                      unawaited(_commitName());
                      _nameFocus.unfocus();
                    },
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: Text(l10n.hiddenSectionDates),
                footer: Text(l10n.hiddenDatesFooter),
                children: <Widget>[
                  for (final SpecialDate date in state.specialDates)
                    CupertinoListTile.notched(
                      title: Text(date.label),
                      additionalInfo: Text(_format(date)),
                      trailing: CupertinoButton(
                        key: ValueKey<String>('remove-${date.label}'),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size.square(44),
                        onPressed: () => cubit.removeSpecialDate(date),
                        child: const Icon(CupertinoIcons.minus_circle, color: CupertinoColors.systemRed),
                      ),
                    ),
                  CupertinoListTile.notched(
                    key: const ValueKey<String>('hidden-add-date'),
                    leading: const Icon(AppIcons.add),
                    title: Text(l10n.hiddenAddDate),
                    onTap: () => _addDate(cubit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _format(SpecialDate date) => '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
}

class _AddDateSheet extends StatefulWidget {
  const _AddDateSheet();

  @override
  State<_AddDateSheet> createState() => _AddDateSheetState();
}

class _AddDateSheetState extends State<_AddDateSheet> {
  final TextEditingController _label = TextEditingController();
  // Год в выборе не важен; високосный 2024, чтобы можно было выбрать 29 февраля.
  DateTime _picked = DateTime(2024);

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoTextField(
                key: const ValueKey<String>('date-label'),
                controller: _label,
                placeholder: l10n.hiddenDateLabelHint,
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _picked,
                minimumDate: DateTime(2024),
                maximumDate: DateTime(2024, 12, 31),
                onDateTimeChanged: (value) => _picked = value,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.hiddenDateCancel),
                ),
                CupertinoButton(
                  key: const ValueKey<String>('date-save'),
                  onPressed: () => Navigator.of(context).pop(
                    SpecialDate(
                      label: _label.text.trim().isEmpty ? l10n.hiddenDateDefaultLabel : _label.text.trim(),
                      month: _picked.month,
                      day: _picked.day,
                    ),
                  ),
                  child: Text(l10n.hiddenDateSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
