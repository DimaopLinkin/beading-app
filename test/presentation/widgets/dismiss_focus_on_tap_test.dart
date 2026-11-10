import 'package:beading/presentation/widgets/dismiss_focus_on_tap.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('тап вне поля снимает фокус, тап по полю оставляет', (tester) async {
    final FocusNode node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: DismissFocusOnTap(
          child: Column(
            children: <Widget>[
              CupertinoTextField(focusNode: node),
              const SizedBox(height: 300, width: 300),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    expect(node.hasFocus, isTrue);

    await tester.tapAt(const Offset(100, 400));
    await tester.pump();
    expect(node.hasFocus, isFalse);
  });
}
