import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/picked_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

void main() {
  test('full — вся картинка, размеры считаются', () {
    expect(CropRect.full.isFull, isTrue);
    const CropRect half = CropRect(left: 0.25, top: 0, right: 0.75, bottom: 0.5);
    expect(half.isFull, isFalse);
    expect(half.width, 0.5);
    expect(half.height, 0.5);
  });

  test('область без площади или за границей запрещена', () {
    expect(() => CropRect(left: 0.5, top: 0, right: 0.5, bottom: 1), throwsA(isA<AssertionError>()));
    expect(() => CropRect(left: -0.1, top: 0, right: 1, bottom: 1), throwsA(isA<AssertionError>()));
    expect(() => CropRect(left: 0, top: 0, right: 1.1, bottom: 1), throwsA(isA<AssertionError>()));
  });

  test('PickedFile узнаёт PDF по сигнатуре, а не по имени', () {
    expect(PickedFile(name: 'a.jpg', bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46, 0x2d])).isPdf, isTrue);
    expect(PickedFile(name: 'a.pdf', bytes: Uint8List.fromList(<int>[1, 2, 3, 4])).isPdf, isFalse);
    expect(PickedFile(name: 'a.pdf', bytes: Uint8List(2)).isPdf, isFalse);
  });
}
