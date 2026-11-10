import 'package:beading/presentation/dev/glass_check_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:beading/presentation/widgets/glass/glass_policy.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpScreen(WidgetTester tester, {bool reduce = false, bool highContrast = false}) => tester.pumpWidget(
  CupertinoApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ru'),
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(highContrast: highContrast),
      child: GlassPolicy(reduceTransparency: reduce, child: AppTheme.builder(context, child)),
    ),
    home: const GlassCheckScreen(),
  ),
);

void main() {
  testWidgets('показывает состояние настроек доступности и прозрачное стекло', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Уменьшить прозрачность: выкл'), findsOneWidget);
    expect(find.text('Повышенная контрастность: выкл'), findsOneWidget);
    expect(find.text('Стекло: прозрачное'), findsOneWidget);
    expect(find.text('Кадров: 0'), findsOneWidget);
  });

  testWidgets('«Уменьшить прозрачность» делает стекло сплошным', (tester) async {
    await pumpScreen(tester, reduce: true);

    expect(find.text('Уменьшить прозрачность: вкл'), findsOneWidget);
    expect(find.text('Стекло: сплошное'), findsOneWidget);
  });

  testWidgets('«Повышенная контрастность» тоже делает стекло сплошным', (tester) async {
    await pumpScreen(tester, highContrast: true);

    expect(find.text('Повышенная контрастность: вкл'), findsOneWidget);
    expect(find.text('Стекло: сплошное'), findsOneWidget);
  });

  testWidgets('схема лежит в своём RepaintBoundary и анимируется', (tester) async {
    await pumpScreen(tester);

    expect(find.descendant(of: find.byType(CupertinoPageScaffold), matching: find.byType(CustomPaint)), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('пауза останавливает движение, продолжить — запускает', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.bySemanticsLabel('Пауза'));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    await tester.tap(find.bySemanticsLabel('Продолжить'));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets('вне профильной сборки предупреждает, что кадры не показательны', (tester) async {
    await pumpScreen(tester);

    expect(find.textContaining('flutter run --profile'), findsOneWidget);
  });

  testWidgets('«Сбросить цифры» не падает', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.bySemanticsLabel('Сбросить цифры'));
    await tester.pump();

    expect(find.text('Кадров: 0'), findsOneWidget);
  });
}
