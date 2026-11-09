import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light и dark фиксируют яркость, system следует за системой', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.system.brightness, isNull);
  });

  test('акцентный цвет одинаков во всех режимах', () {
    expect(AppTheme.light.primaryColor, AppTheme.dark.primaryColor);
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets('приложение собирается в теме $brightness', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
          builder: AppTheme.builder,
          home: Builder(
            builder: (context) => Text('${CupertinoTheme.brightnessOf(context)}', textDirection: TextDirection.ltr),
          ),
        ),
      );

      expect(find.text('$brightness'), findsOneWidget);
    });
  }
}
