import 'dart:ui';

import 'package:beading/presentation/grid_pattern/stitch_cells.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Color surface = Color(0xFFF7F4EF);

  test('белый и молочный сливаются с подложкой, цветные нет', () {
    expect(StitchCells.blendsIntoSurface(const Color(0xFFFFFFFF), surface), isTrue);
    expect(StitchCells.blendsIntoSurface(const Color(0xFFFAF3E0), surface), isTrue);
    expect(StitchCells.blendsIntoSurface(const Color(0xFFC80A14), surface), isFalse);
    expect(StitchCells.blendsIntoSurface(const Color(0xFF1E2832), surface), isFalse);
  });

  test('на тёмной подложке сливается чёрный, а не белый', () {
    const Color dark = Color(0xFF151316);
    expect(StitchCells.blendsIntoSurface(const Color(0xFF000000), dark), isTrue);
    expect(StitchCells.blendsIntoSurface(const Color(0xFFFFFFFF), dark), isFalse);
  });
}
