import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Обработчики пунктов меню. `null` — пункт неактивен (экран, где действие не нужно, его не задаёт).
class AppMenuActions {
  const AppMenuActions({this.onUndo, this.onRedo, this.onPreferences});

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onPreferences;
}

/// Нативная строка меню macOS (ADR-0001): меню приложения (О программе, «Настройки…» ⌘,, Скрыть, Выйти ⌘Q),
/// Правка (⌘Z, ⇧⌘Z) и Окно. Пока ни один экран не задаёт обработчики, пункты правки и настроек неактивны.
/// На других платформах возвращает [child] без изменений.
class AppMenuBar extends StatelessWidget {
  const AppMenuBar({
    required this.child,
    this.actions = const AppMenuActions(),
    this.platform,
    this.undoLabel = 'Отменить',
    this.redoLabel = 'Повторить',
    this.appLabel = 'Бисер',
    this.editLabel = 'Правка',
    this.preferencesLabel = 'Настройки…',
    super.key,
  });

  final Widget child;
  final AppMenuActions actions;
  final TargetPlatform? platform;
  final String undoLabel;
  final String redoLabel;
  final String appLabel;
  final String editLabel;
  final String preferencesLabel;

  @override
  Widget build(BuildContext context) {
    if ((platform ?? defaultTargetPlatform) != TargetPlatform.macOS) {
      return child;
    }
    return PlatformMenuBar(
      menus: <PlatformMenuItem>[
        PlatformMenu(
          label: appLabel,
          menus: <PlatformMenuItem>[
            const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
            PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformMenuItem(
                  label: preferencesLabel,
                  shortcut: const SingleActivator(LogicalKeyboardKey.comma, meta: true),
                  onSelected: actions.onPreferences,
                ),
              ],
            ),
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.servicesSubmenu),
              ],
            ),
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hideOtherApplications),
                PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.showAllApplications),
              ],
            ),
            const PlatformMenuItemGroup(
              members: <PlatformMenuItem>[PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit)],
            ),
          ],
        ),
        PlatformMenu(
          label: editLabel,
          menus: <PlatformMenuItem>[
            PlatformMenuItem(
              label: undoLabel,
              shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
              onSelected: actions.onUndo,
            ),
            PlatformMenuItem(
              label: redoLabel,
              shortcut: const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true),
              onSelected: actions.onRedo,
            ),
          ],
        ),
        const PlatformMenu(
          label: 'Окно',
          menus: <PlatformMenuItem>[
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.minimizeWindow),
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.zoomWindow),
          ],
        ),
      ],
      child: child,
    );
  }
}
