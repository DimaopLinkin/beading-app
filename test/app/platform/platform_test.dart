import 'package:beading/app/platform/app_lifecycle_binding.dart';
import 'package:beading/app/platform/app_menu_bar.dart';
import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/orientation_lock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('окно macOS по умолчанию 480×900, минимум 400×700, скрытый заголовок', () {
    const DesktopWindowConfig config = DesktopWindowConfig();

    expect(config.size, const Size(480, 900));
    expect(config.minimumSize, const Size(400, 700));
    expect(config.hiddenTitleBar, isTrue);
  });

  test('вне macOS окно не настраивается и плагин не вызывается', () async {
    await WindowManagerDesktopWindow(platform: TargetPlatform.iOS).configure(const DesktopWindowConfig());
  });

  test('SystemChrome получает только portraitUp', () async {
    final List<MethodCall> calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await const SystemChromeOrientationLock().lockPortrait();

    final MethodCall call = calls.singleWhere((c) => c.method == 'SystemChrome.setPreferredOrientations');
    expect(call.arguments, <String>['DeviceOrientation.portraitUp']);
  });

  group('AppLifecycleBinding', () {
    late FakeScreenWakeLock lock;
    late AppLifecycleBinding binding;

    setUp(() async {
      lock = FakeScreenWakeLock();
      final controller = fakeWakelockController(lock);
      await controller.start();
      binding = AppLifecycleBinding(controller);
    });

    tearDown(() => binding.dispose());

    test('paused/hidden/detached — фон, resumed — передний план, inactive экран не отпускает', () async {
      await binding.onStateChanged(AppLifecycleState.inactive);
      expect(lock.calls, <String>['enable']);

      await binding.onStateChanged(AppLifecycleState.paused);
      expect(lock.calls.last, 'disable');

      await binding.onStateChanged(AppLifecycleState.resumed);
      expect(lock.calls.last, 'enable');

      await binding.onStateChanged(AppLifecycleState.hidden);
      expect(lock.calls.last, 'disable');

      await binding.onStateChanged(AppLifecycleState.resumed);
      await binding.onStateChanged(AppLifecycleState.detached);
      expect(lock.calls.last, 'disable');
    });
  });

  group('AppMenuBar', () {
    const Widget child = SizedBox(key: Key('child'));

    testWidgets('вне macOS возвращает child без меню', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: AppMenuBar(platform: TargetPlatform.iOS, child: child),
        ),
      );

      expect(find.byType(PlatformMenuBar), findsNothing);
      expect(find.byKey(const Key('child')), findsOneWidget);
    });

    testWidgets('на macOS есть ⌘Z, ⇧⌘Z и ⌘, с нужными обработчиками', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final List<String> fired = <String>[];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: AppMenuBar(
            platform: TargetPlatform.macOS,
            actions: AppMenuActions(
              onUndo: () => fired.add('undo'),
              onRedo: () => fired.add('redo'),
              onPreferences: () => fired.add('prefs'),
            ),
            child: child,
          ),
        ),
      );

      debugDefaultTargetPlatformOverride = null;
      final PlatformMenuBar bar = tester.widget(find.byType(PlatformMenuBar));
      final List<PlatformMenuItem> all = bar.menus
          .expand((m) => m is PlatformMenu ? m.menus : <PlatformMenuItem>[m])
          .expand((m) => m is PlatformMenuItemGroup ? m.members : <PlatformMenuItem>[m])
          .toList();
      expect(
        all.whereType<PlatformProvidedMenuItem>().map((i) => i.type),
        containsAll(<PlatformProvidedMenuItemType>[
          PlatformProvidedMenuItemType.about,
          PlatformProvidedMenuItemType.hide,
          PlatformProvidedMenuItemType.quit,
          PlatformProvidedMenuItemType.minimizeWindow,
        ]),
      );
      final List<PlatformMenuItem> items = all.where((i) => i is! PlatformProvidedMenuItem).toList();
      final Map<String, SingleActivator> shortcuts = <String, SingleActivator>{
        for (final PlatformMenuItem item in items) item.label: item.shortcut! as SingleActivator,
      };

      expect(shortcuts['Отменить'], const SingleActivator(LogicalKeyboardKey.keyZ, meta: true));
      expect(shortcuts['Повторить'], const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true));
      expect(shortcuts['Настройки…'], const SingleActivator(LogicalKeyboardKey.comma, meta: true));

      for (final PlatformMenuItem item in items) {
        item.onSelected!();
      }
      expect(fired, <String>['prefs', 'undo', 'redo']);
    });
  });
}
