import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/image_to_grid/size_suggester.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:flutter_test/flutter_test.dart';

SizeProbe probe(int columns, double? correlation) =>
    SizeProbe(columns: columns, colors: columns ~/ 6, correlation: correlation);

void main() {
  const SizeSuggester suggester = SizeSuggester();

  group('SizeSuggester.choose', () {
    test('берёт самую узкую пробу, достигшую порога', () {
      final SizeSuggestion? hint = suggester.choose(<SizeProbe>[probe(60, 0.93), probe(30, 0.80), probe(40, 0.91)]);
      expect(hint, const SizeSuggestion(columns: 40, colors: 6, reached: true));
    });

    test('порог не достигнут: берётся самая крупная проба и reached = false', () {
      final SizeSuggestion? hint = suggester.choose(<SizeProbe>[probe(30, 0.4), probe(120, 0.7)]);
      expect(hint?.columns, 120);
      expect(hint?.reached, isFalse);
    });

    test('минимум ширины поднимает ответ', () {
      final SizeSuggestion? hint = suggester.choose(<SizeProbe>[
        probe(30, 0.95),
        probe(60, 0.96),
        probe(100, 0.97),
      ], minColumns: 80);
      expect(hint?.columns, 100);
    });

    test('пробы без корреляции пропускаются; все пустые — нет подсказки', () {
      expect(suggester.choose(<SizeProbe>[probe(30, null), probe(60, 0.95)])?.columns, 60);
      expect(suggester.choose(<SizeProbe>[probe(30, null)]), isNull);
      expect(suggester.choose(const <SizeProbe>[]), isNull);
    });
  });

  group('SizeSuggester.candidates', () {
    test('бисер: до предела, цвета растут с шириной', () {
      final List<({int columns, int colors})> c = SizeSuggester.candidates(Craft.beading, maxColumns: 100);
      expect(c.map((e) => e.columns), <int>[30, 40, 60, 80, 100]);
      expect(c.first.colors, 8);
      expect(c.last.colors, 16);
    });

    test('вышивка: 110–200 клеток и 30 цветов', () {
      final List<({int columns, int colors})> c = SizeSuggester.candidates(Craft.crossStitch, maxColumns: 250);
      expect(c.first.columns, 110);
      expect(c.last.columns, 200);
      expect(c.every((e) => e.colors == 30), isTrue);
    });
  });

  test('сантиметры согласованы с канвой (T36): аида 11, 14 и 18', () {
    for (final int count in <int>[11, 14, 18]) {
      final Fabric fabric = Fabric.create(kind: FabricKind.aida, count: count).valueOrNull!;
      expect(SizeSuggester.centimetres(150, fabric), closeTo(150 * 2.54 / count, 1e-9));
      expect(SizeSuggester.centimetres(150, fabric), closeTo(fabric.cmForCells(150), 1e-9));
    }
  });

  test('сантиметры бисера считаются по ширине бусины', () {
    expect(SizeSuggester.centimetres(100, BeadSize.delica11), closeTo(100 * BeadSize.delica11.widthMm / 10, 1e-9));
  });
}
