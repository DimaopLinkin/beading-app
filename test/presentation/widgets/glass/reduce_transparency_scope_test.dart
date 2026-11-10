import 'package:beading/domain/settings/reduce_transparency_source.dart';
import 'package:beading/presentation/widgets/glass/glass_policy.dart';
import 'package:beading/presentation/widgets/glass/reduce_transparency_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_platform.dart';

void main() {
  bool? opaque;

  Widget app(ReduceTransparencySource source) => Directionality(
    textDirection: TextDirection.ltr,
    child: ReduceTransparencyScope(
      source: source,
      child: Builder(
        builder: (context) {
          opaque = GlassPolicy.isOpaque(context);
          return const SizedBox();
        },
      ),
    ),
  );

  setUp(() => opaque = null);

  testWidgets('пока ответа нет, стекло прозрачное', (tester) async {
    await tester.pumpWidget(app(FakeReduceTransparencySource(initial: true)));

    expect(opaque, isFalse);
  });

  testWidgets('значение платформы включает непрозрачную заливку', (tester) async {
    await tester.pumpWidget(app(FakeReduceTransparencySource(initial: true)));
    await tester.pump();

    expect(opaque, isTrue);
  });

  testWidgets('смена настройки в системе применяется сразу', (tester) async {
    final FakeReduceTransparencySource source = FakeReduceTransparencySource();
    await tester.pumpWidget(app(source));
    await tester.pump();
    expect(opaque, isFalse);

    source.controller.add(true);
    await tester.idle();
    await tester.pump();
    expect(opaque, isTrue);

    source.controller.add(false);
    await tester.idle();
    await tester.pump();
    expect(opaque, isFalse);
  });

  testWidgets('событие новее первого ответа: старый ответ его не затирает', (tester) async {
    final FakeReduceTransparencySource source = FakeReduceTransparencySource();
    await tester.pumpWidget(app(source));

    source.controller.add(true);
    await tester.idle();
    await tester.pump();

    expect(opaque, isTrue);
  });

  testWidgets('замена источника переподписывается, старый поток отпускается', (tester) async {
    final FakeReduceTransparencySource first = FakeReduceTransparencySource();
    final FakeReduceTransparencySource second = FakeReduceTransparencySource(initial: true);
    await tester.pumpWidget(app(first));
    await tester.pump();

    await tester.pumpWidget(app(second));
    await tester.pump();
    expect(opaque, isTrue);
    expect(first.controller.hasListener, isFalse);
    expect(second.controller.hasListener, isTrue);
  });

  testWidgets('после удаления виджета подписки нет', (tester) async {
    final FakeReduceTransparencySource source = FakeReduceTransparencySource();
    await tester.pumpWidget(app(source));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());

    expect(source.controller.hasListener, isFalse);
  });
}
