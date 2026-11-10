import 'dart:async';

import 'package:beading/domain/settings/app_theme_mode.dart';
import 'package:beading/domain/settings/bead_brands.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/settings/settings_state.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';
import 'package:beading/presentation/sharing/share_origin.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Экран «Настройки». Нужны [SettingsCubit] и [ThemeModeCubit] выше по дереву.
///
/// Резервная копия работает, если передан [dataTransfer] (T21); синхронизация — заглушка «Скоро» до T28.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.onOpenAbout, this.onOpenGlassCheck, this.dataTransfer, super.key});

  /// Резервная копия и восстановление; `null` — пункты «Скоро».
  final DataTransferCubit? dataTransfer;

  final VoidCallback onOpenAbout;

  /// Раздел «Для разработки» (проверка стекла на устройстве); `null` в релизной сборке.
  final VoidCallback? onOpenGlassCheck;

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
                    if (dataTransfer == null)
                      CupertinoListTile.notched(
                        key: const ValueKey<String>('settings-backup'),
                        title: Text(l10n.settingsBackup),
                        additionalInfo: Text(l10n.settingsSoon),
                      )
                    else ...<Widget>[
                      Builder(
                        builder: (tileContext) => CupertinoListTile.notched(
                          key: const ValueKey<String>('settings-backup'),
                          title: Text(l10n.settingsBackupCreate),
                          trailing: const CupertinoListTileChevron(),
                          onTap: () => unawaited(dataTransfer!.backup(origin: shareOriginOf(tileContext))),
                        ),
                      ),
                      CupertinoListTile.notched(
                        key: const ValueKey<String>('settings-restore'),
                        title: Text(l10n.settingsRestore),
                        trailing: const CupertinoListTileChevron(),
                        onTap: () => unawaited(dataTransfer!.pickAndPreview()),
                      ),
                    ],
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
                if (onOpenGlassCheck != null)
                  CupertinoListSection.insetGrouped(
                    header: Text(l10n.settingsSectionDev),
                    children: <Widget>[
                      CupertinoListTile.notched(
                        key: const ValueKey<String>('settings-glass-check'),
                        title: Text(l10n.settingsGlassCheck),
                        trailing: const CupertinoListTileChevron(),
                        onTap: onOpenGlassCheck,
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
