import 'package:beading/app/platform/desktop_window.dart';
import 'package:beading/app/platform/title_bar_inset.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<EdgeInsets> padding(WidgetTester tester, TargetPlatform platform, {EdgeInsets outer = EdgeInsets.zero}) async {
    late EdgeInsets result;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(padding: outer, viewPadding: outer),
        child: TitleBarInset(
          platform: platform,
          child: Builder(
            builder: (context) {
              result = MediaQuery.paddingOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return result;
  }

  testWidgets('на macOS сверху появляется отступ под кнопки окна', (tester) async {
    final EdgeInsets result = await padding(tester, TargetPlatform.macOS);
    expect(result.top, macTitleBarInset);
  });

  testWidgets('на macOS остальные отступы не меняются', (tester) async {
    final EdgeInsets result = await padding(tester, TargetPlatform.macOS, outer: const EdgeInsets.only(bottom: 5));
    expect(result, const EdgeInsets.only(top: macTitleBarInset, bottom: 5));
  });

  testWidgets('на iOS отступ не добавляется', (tester) async {
    final EdgeInsets result = await padding(tester, TargetPlatform.iOS, outer: const EdgeInsets.only(top: 47));
    expect(result.top, 47);
  });

  testWidgets('если отступ сверху уже больше, он остаётся', (tester) async {
    final EdgeInsets result = await padding(tester, TargetPlatform.macOS, outer: const EdgeInsets.only(top: 40));
    expect(result.top, 40);
  });
}
