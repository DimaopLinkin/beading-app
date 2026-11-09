import 'dart:async';

import 'package:beading/domain/easter_eggs/shown_compliment.dart';
import 'package:beading/presentation/easter_eggs/compliment_banner_cubit.dart';
import 'package:beading/presentation/easter_eggs/compliment_overlay.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<ShownCompliment> source;
  late ComplimentBannerCubit cubit;
  late List<MethodCall> haptics;

  setUp(() {
    haptics = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (
        call,
      ) async {
        haptics.add(call);
        return null;
      },
    );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
  });

  Future<void> _pump(WidgetTester tester, Brightness brightness) => tester.pumpWidget(
    CupertinoApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      builder: (context, app) => AppTheme.builder(
        context,
        BlocProvider<ComplimentBannerCubit>(
          // Виджет закрывает cubit при уничтожении дерева: так таймер не переживает тест.
          create: (_) => cubit,
          child: ComplimentOverlay(child: app ?? const SizedBox.shrink()),
        ),
      ),
      home: const CupertinoPageScaffold(child: Center(child: Text('Экран'))),
    ),
  );

  // Поток и cubit создаются внутри теста, чтобы их таймеры работали на часах теста.
  Future<void> pumpOverlay(WidgetTester tester, {Brightness brightness = Brightness.light}) {
    source = StreamController<ShownCompliment>(sync: true);
    cubit = ComplimentBannerCubit(source.stream);
    addTearDown(() async {
      await source.close();
    });
    return _pump(tester, brightness);
  }

  Future<void> show(WidgetTester tester, String text) async {
    source.add(ShownCompliment(text));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('без комплимента виден только экран', (tester) async {
    await pumpOverlay(tester);

    expect(find.text('Экран'), findsOneWidget);
    expect(find.byType(ComplimentBanner), findsNothing);
  });

  testWidgets('показывает текст поверх экрана, экран остаётся на месте, лёгкая вибрация', (tester) async {
    await pumpOverlay(tester);

    await show(tester, 'Настя, это шедевр');

    expect(find.text('Настя, это шедевр'), findsOneWidget);
    expect(find.text('Экран'), findsOneWidget);
    expect(
      haptics.where((c) => c.method == 'HapticFeedback.vibrate' && c.arguments == 'HapticFeedbackType.lightImpact'),
      hasLength(1),
    );
  });

  testWidgets('исчезает сам через 5 секунд', (tester) async {
    await pumpOverlay(tester);
    await show(tester, 'Привет');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Привет'), findsNothing);
  });

  testWidgets('закрывается свайпом вверх', (tester) async {
    await pumpOverlay(tester);
    await show(tester, 'Привет');

    await tester.drag(find.text('Привет'), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(find.text('Привет'), findsNothing);
    expect(cubit.state, isNull);
  });

  testWidgets('свайп вниз не закрывает', (tester) async {
    await pumpOverlay(tester);
    await show(tester, 'Привет');

    await tester.drag(find.text('Привет'), const Offset(0, 100));
    await tester.pumpAndSettle();

    expect(find.text('Привет'), findsOneWidget);
  });

  testWidgets('не перекрывает нижние 120pt и не мешает нажатиям вне баннера', (tester) async {
    await pumpOverlay(tester);
    await show(tester, 'Привет');

    final Rect banner = tester.getRect(find.byType(ComplimentBanner));
    final double screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;

    expect(banner.bottom, lessThanOrEqualTo(screenHeight - 120));
    expect(banner.top, greaterThanOrEqualTo(0));
  });

  testWidgets('длинный текст переносится на вторую строку и не вылезает за экран', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpOverlay(tester);

    await show(tester, 'Ты так увлечена. Не забудь размять плечи и выпить воды');

    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byType(ComplimentBanner)).right, lessThanOrEqualTo(320));
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('строится в теме $brightness', (tester) async {
      await pumpOverlay(tester, brightness: brightness);

      await show(tester, 'Привет');

      expect(find.text('Привет'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('есть подпись для VoiceOver', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpOverlay(tester);

    await show(tester, 'Привет');

    expect(find.bySemanticsLabel('Привет'), findsOneWidget);
    handle.dispose();
  });
}
