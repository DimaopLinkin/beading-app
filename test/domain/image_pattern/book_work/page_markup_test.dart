import 'dart:typed_data';

import 'package:beading/domain/image_pattern/book_work/page_markup.dart';
import 'package:flutter_test/flutter_test.dart';

MarkerStroke _line(double x1, double y1, double x2, double y2, {int rgb = 0xFFE45C, double width = 0.0625}) =>
    MarkerStroke(rgb: rgb, width: width, points: <double>[x1, y1, x2, y2]);

void main() {
  group('PageMarkupCodec', () {
    test('круг: encode → decode возвращает те же мазки', () {
      final PageMarkup markup = PageMarkup(<MarkerStroke>[
        _line(0.25, 0.5, 0.5, 0.75),
        MarkerStroke(rgb: 0x7CC8FF, width: 0.125, points: const <double>[0.5, 0.5]),
      ]);
      expect(PageMarkupCodec.decode(PageMarkupCodec.encode(markup)), markup);
    });

    test('пустые пометки', () {
      expect(PageMarkupCodec.decode(PageMarkupCodec.encode(const PageMarkup.empty()))!.isEmpty, isTrue);
      expect(PageMarkupCodec.decode(Uint8List(0))!.isEmpty, isTrue);
    });

    test('битые байты не падают: неизвестная версия, обрыв, мазок без точек, чудовищное число мазков', () {
      final Uint8List good = PageMarkupCodec.encode(PageMarkup(<MarkerStroke>[_line(0.1, 0.1, 0.2, 0.2)]));
      expect(PageMarkupCodec.decode(Uint8List.fromList(<int>[9, ...good.skip(1)])), isNull);
      expect(PageMarkupCodec.decode(good.sublist(0, good.length - 3)), isNull);
      expect(PageMarkupCodec.decode(Uint8List.fromList(<int>[1, 255, 255, 255, 255])), isNull);
      final Uint8List noPoints = Uint8List.fromList(good)..buffer.asByteData().setUint32(13, 0, Endian.little);
      expect(PageMarkupCodec.decode(noPoints), isNull);
    });
  });

  group('PageMarkup', () {
    test('мазки добавляются сверху', () {
      final PageMarkup m = PageMarkup().withStroke(_line(0, 0, 1, 0)).withStroke(_line(0, 1, 1, 1));
      expect(m.strokes.length, 2);
      expect(m.strokes.last.points[1], 1);
    });

    test('ластик убирает только задетые мазки целиком', () {
      final PageMarkup m = PageMarkup(<MarkerStroke>[_line(0, 0.1, 1, 0.1), _line(0, 0.9, 1, 0.9)]);
      final PageMarkup erased = m.erasing(<double>[0.5, 0.12], 0.02);
      expect(erased.strokes.length, 1);
      expect(erased.strokes.single.points[1], closeTo(0.9, 1e-6));
      expect(identical(m.erasing(<double>[0.5, 0.5], 0.02), m), isTrue, reason: 'ничего не задето — тот же объект');
    });

    test('мазок из одной точки задевается кругом ластика с учётом толщины', () {
      final MarkerStroke dot = MarkerStroke(rgb: 1, width: 0.04, points: const <double>[0.5, 0.5]);
      expect(dot.touches(0.5, 0.55, 0.04), isTrue);
      expect(dot.touches(0.5, 0.7, 0.04), isFalse);
    });
  });
}
