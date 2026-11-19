import 'package:beading/presentation/theme/app_theme.dart';
import 'package:beading/presentation/widgets/wheel_scale.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(double value, ValueChanged<double> onChanged) => CupertinoApp(
    theme: AppTheme.light,
    builder: AppTheme.builder,
    home: Center(
      child: SizedBox(
        width: 300,
        child: WheelScale(
          key: const ValueKey<String>('wheel'),
          value: value,
          min: 0,
          max: 100,
          step: 5,
          onChanged: onChanged,
        ),
      ),
    ),
  );

  testWidgets('прокрутка шкалы пальцем меняет значение на шаг за деление и защёлкивается', (tester) async {
    final List<double> seen = <double>[];
    await tester.pumpWidget(host(50, seen.add));
    // Шкала едет влево, когда тянут палец влево: значение растёт. Одно деление = 12 px, один шаг = 5 (часть жеста съедает порог касания).
    await tester.drag(find.byKey(const ValueKey<String>('wheel')), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(seen, isNotEmpty);
    expect(seen.last, greaterThan(50));
    expect(seen.last % 5, 0);
  });

  testWidgets('границы: у минимума дальше не едет, значение извне двигает шкалу', (tester) async {
    final List<double> seen = <double>[];
    await tester.pumpWidget(host(0, seen.add));
    await tester.drag(find.byKey(const ValueKey<String>('wheel')), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(seen, isEmpty);
    await tester.pumpWidget(host(100, seen.add));
    await tester.pumpAndSettle();
    expect(seen, isEmpty, reason: 'смена значения снаружи не считается жестом пользователя');
  });
}
