import 'dart:typed_data';

import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/importance_brush.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PreparedFrame', () {
    test('перевод туда и обратно для всех поворотов и обрезки', () {
      const CropRect crop = CropRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8);
      for (int q = 0; q < 4; q++) {
        final PreparedFrame frame = PreparedFrame(width: 80, height: 60, quarterTurns: q, crop: crop);
        final (double, double) p = frame.toPrepared(0.3, 0.6);
        final (double, double) back = frame.toSource(p.$1, p.$2);
        expect(back.$1, closeTo(0.3, 1e-9));
        expect(back.$2, closeTo(0.6, 1e-9));
      }
    });

    test('поворот по часовой: левый верх уходит в правый верх', () {
      const PreparedFrame frame = PreparedFrame(width: 10, height: 10, quarterTurns: 1);
      final (double, double) p = frame.toPrepared(0, 0);
      expect(p.$1, closeTo(1, 1e-9));
      expect(p.$2, closeTo(0, 1e-9));
    });
  });

  group('ImportanceBrush', () {
    const PreparedFrame frame = PreparedFrame(width: 20, height: 20);
    const BrushStroke stroke = BrushStroke(points: <double>[0.5, 0.5], radius: 0.1);

    test('без мазков веса не меняются', () {
      final Float32List w = Float32List(400)..fillRange(0, 400, 0.5);
      expect(ImportanceBrush.empty.applyTo(w, frame), same(w));
      expect(ImportanceBrush.empty.applyTo(null, frame), isNull);
    });

    test('мазок поднимает вес под собой и не трогает остальное', () {
      final Float32List w = Float32List(400)..fillRange(0, 400, 0.5);
      final Float32List out = const ImportanceBrush(<BrushStroke>[stroke]).applyTo(w, frame)!;
      expect(out[10 * 20 + 10], ImportanceBrush.weight);
      expect(out[0], 0.5);
      expect(w[10 * 20 + 10], 0.5);
    });

    test('без маски фон весит 1', () {
      final Float32List out = const ImportanceBrush(<BrushStroke>[stroke]).applyTo(null, frame)!;
      expect(out[0], 1);
      expect(out[10 * 20 + 10], ImportanceBrush.weight);
    });

    test('мазок остаётся на тех же клетках после поворота', () {
      const PreparedFrame turned = PreparedFrame(width: 20, height: 20, quarterTurns: 1);
      const BrushStroke corner = BrushStroke(points: <double>[0, 0], radius: 0.1);
      final Float32List out = const ImportanceBrush(<BrushStroke>[corner]).applyTo(null, turned)!;
      expect(out[0 * 20 + 19], ImportanceBrush.weight, reason: 'левый верх стал правым верхом');
      expect(out[0], 1);
    });

    test('мазок вне обрезки ничего не меняет', () {
      const PreparedFrame cropped = PreparedFrame(
        width: 20,
        height: 20,
        crop: CropRect(left: 0.5, top: 0.5, right: 1, bottom: 1),
      );
      const BrushStroke away = BrushStroke(points: <double>[0.05, 0.05], radius: 0.02);
      final Float32List out = const ImportanceBrush(<BrushStroke>[away]).applyTo(null, cropped)!;
      expect(out.every((v) => v == 1), isTrue);
    });

    test('ластик стирает только задетые мазки', () {
      const BrushStroke far = BrushStroke(points: <double>[0.1, 0.1], radius: 0.02);
      const ImportanceBrush brush = ImportanceBrush(<BrushStroke>[stroke, far]);
      final ImportanceBrush after = brush.erasing(<double>[0.5, 0.5], 0.03, frame);
      expect(after.strokes, <BrushStroke>[far]);
      expect(brush.erasing(<double>[0.9, 0.9], 0.01, frame), same(brush));
    });
  });
}
