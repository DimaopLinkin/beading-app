import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/bead_brands.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/settings/settings_state.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Экран «Настройки». Нужны [SettingsCubit] и [ThemeModeCubit] выше по дереву.
///
/// Резервная копия и синхронизация — заглушки «Скоро»: T21 и T28 заменят их рабочими пунктами.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.onOpenAbout, super.key});

  final VoidCallback onOpenAbout;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.settingsTitle)),
      child: SafeArea(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final SettingsCubit cubit = context.read<SettingsCubit>();
            return ListView(
              children: <Widget>[
                if (state.saveFailed) _SaveFailedBanner(text: l10n.settingsSaveFailed),
                CupertinoListSection.insetGrouped(
                  header: Text(l10n.settingsSectionAppearance),
                  children: <Widget>[_ThemeTile(label: l10n.settingsThemeLabel)],
                ),
                CupertinoListSection.insetGrouped(
                  header: Text(l10n.settingsSectionWork),
                  footer: Text('${l10n.settingsKeepScreenAwakeFooter} ${l10n.settingsSymbolModeFooter}'),
                  children: <Widget>[
                    CupertinoListTile.notched(
                      title: Text(l10n.settingsKeepScreenAwake),
                      trailing: CupertinoSwitch(
                        key: const ValueKey<String>('keep-screen-awake'),
                        value: state.keepScreenAwake,
                        onChanged: (value) => cubit.setKeepScreenAwake(value: value),
                      ),
                    ),
                    CupertinoListTile.notched(
                      title: Text(l10n.settingsSymbolMode),
                      trailing: CupertinoSwitch(
                        key: const ValueKey<String>('symbol-mode'),
                        value: state.symbolMode,
                        onChanged: (value) => cubit.setSymbolMode(value: value),
                      ),
                    ),
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('default-brand'),
                      title: Text(l10n.settingsDefaultBrand),
                      additionalInfo: Text(state.defaultBeadBrand),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () => _pickBrand(context, cubit, state.defaultBeadBrand),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  header: Text(l10n.settingsSectionData),
                  children: <Widget>[
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('settings-backup'),
                      title: Text(l10n.settingsBackup),
                      additionalInfo: Text(l10n.settingsSoon),
                    ),
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('settings-sync'),
                      title: Text(l10n.settingsSync),
                      additionalInfo: Text(l10n.settingsSoon),
                    ),
                  ],
                ),
                CupertinoListSection.insetGrouped(
                  children: <Widget>[
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('settings-about'),
                      title: Text(l10n.settingsAbout),
                      trailing: const CupertinoListTileChevron(),
                      onTap: onOpenAbout,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickBrand(BuildContext context, SettingsCubit cubit, String current) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        title: Text(l10n.settingsDefaultBrand),
        actions: <Widget>[
          for (final String brand in beadBrandChoices)
            CupertinoActionSheetAction(
              isDefaultAction: brand == current,
              onPressed: () {
                cubit.setDefaultBeadBrand(brand);
                Navigator.of(popupContext).pop();
              },
              child: Text(brand),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: Text(l10n.cancel),
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return BlocBuilder<ThemeModeCubit, AppThemeMode>(
      builder: (context, mode) => Padding(
        padding: EdgeInsets.all(tokens.spacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label),
            SizedBox(height: tokens.spacing.s),
            SizedBox(
              width: double.infinity,
              child: CupertinoSlidingSegmentedControl<AppThemeMode>(
                key: const ValueKey<String>('theme-mode'),
                groupValue: mode,
                onValueChanged: (value) {
                  if (value != null) context.read<ThemeModeCubit>().select(value);
                },
                children: <AppThemeMode, Widget>{
                  AppThemeMode.system: Text(l10n.settingsThemeSystem),
                  AppThemeMode.light: Text(l10n.settingsThemeLight),
                  AppThemeMode.dark: Text(l10n.settingsThemeDark),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveFailedBanner extends StatelessWidget {
  const _SaveFailedBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(context.tokens.spacing.l),
    child: Text(text, style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context))),
  );
}
