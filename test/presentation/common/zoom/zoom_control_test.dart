import 'package:beading/presentation/common/zoom/canvas_zoom.dart';
import 'package:beading/presentation/common/zoom/zoom_control.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glass_harness.dart';

void main() {
  test('ползунок логарифмический и обратимый', () {
    expect(ZoomControl.sliderValue(1, 1, 16), 0);
    expect(ZoomControl.sliderValue(16, 1, 16), 1);
    expect(ZoomControl.sliderValue(4, 1, 16), closeTo(0.5, 1e-9));
    expect(ZoomControl.scaleAt(0.5, 1, 16), closeTo(4, 1e-9));
  });

  testWidgets('кнопки и процент: 100% = схема целиком', (tester) async {
    final CanvasZoom zoom = CanvasZoom(controller: TransformationController(), maxScale: 8)..minScale = 0.5;
    zoom.controller.value = Matrix4.diagonal3Values(0.5, 0.5, 1);
    await pumpGlass(tester, ZoomControl(zoom: zoom, viewport: const Size(400, 300)));
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('zoom-in')));
    await tester.pump();
    expect(find.text('125%'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('zoom-out')));
    await tester.tap(find.byKey(const ValueKey<String>('zoom-out')));
    await tester.pump();
    expect(zoom.scale, closeTo(0.5, 1e-9));
  });
}
