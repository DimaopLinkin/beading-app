import 'package:beading/presentation/widgets/min_tap_target.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glass_harness.dart';

void main() {
  testWidgets('малый ребёнок получает область не меньше 44 pt', (tester) async {
    await pumpGlass(tester, const MinTapTarget(child: SizedBox(width: 20, height: 20)));

    expect(tester.getSize(find.byType(MinTapTarget)), const Size(44, 44));
  });

  testWidgets('большой ребёнок не уменьшается и не растягивается', (tester) async {
    await pumpGlass(tester, const MinTapTarget(child: SizedBox(width: 120, height: 60)));

    expect(tester.getSize(find.byType(MinTapTarget)), const Size(120, 60));
  });

  testWidgets('не растягивается на всю доступную ширину', (tester) async {
    await pumpGlass(
      tester,
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: const MinTapTarget(child: SizedBox(width: 20, height: 20)),
      ),
    );

    expect(tester.getSize(find.byType(MinTapTarget)).width, 44);
  });

  testWidgets('касание рядом с малым ребёнком, но внутри 44 pt, срабатывает', (tester) async {
    var taps = 0;
    await pumpGlass(
      tester,
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => taps++,
        child: const MinTapTarget(child: SizedBox(width: 20, height: 20)),
      ),
    );

    await tester.tapAt(tester.getTopLeft(find.byType(MinTapTarget)) + const Offset(2, 2));

    expect(taps, 1);
  });
}
