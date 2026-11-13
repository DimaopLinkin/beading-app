import 'package:beading/domain/printing/print_layout.dart';
import 'package:beading/domain/printing/print_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrintLayout: масштаб и поля', () {
    for (final PrintPaper paper in PrintPaper.values) {
      test('${paper.name}: клетка 3 мм, сетка и подписи помещаются на лист', () {
        final PrintLayout layout = PrintLayout(paper);
        expect(layout.cellPx, 3 * paper.pixelsPerMm, reason: '10 крестиков = 3 см');
        expect(layout.pageWidthPx, paper.widthMm * paper.pixelsPerMm);
        expect(layout.tileColumns % 10, 0);
        expect(layout.tileRows % 10, 0);
        final int right = layout.gridLeftPx + layout.tileColumns * layout.cellPx + layout.axisPx;
        expect(right, lessThanOrEqualTo(layout.pageWidthPx - layout.marginPx));
        final int bottom = layout.gridTopPx + layout.tileRows * layout.cellPx + layout.axisPx + layout.footerPx;
        expect(bottom, lessThanOrEqualTo(layout.pageHeightPx - layout.marginPx));
      });
    }

    test('больший формат даёт больше клеток на странице', () {
      expect(PrintLayout(PrintPaper.a3).tileColumns, greaterThan(PrintLayout(PrintPaper.a4).tileColumns));
      expect(PrintLayout(PrintPaper.a2).tileRows, greaterThan(PrintLayout(PrintPaper.a3).tileRows));
    });
  });

  group('нарезка и число страниц', () {
    final PrintLayout a4 = PrintLayout(PrintPaper.a4);

    test('страницы по строкам, края короче, клетки не теряются', () {
      final int tc = a4.tileColumns;
      final int tr = a4.tileRows;
      final List<PrintTile> tiles = a4.tiles(columns: tc * 2 + 15, rows: tr + 20);
      expect(tiles, hasLength(6));
      expect(tiles.first, PrintTile(column: 0, row: 0, columns: tc, rows: tr));
      expect(tiles.last, PrintTile(column: tc * 2, row: tr, columns: 15, rows: 20));
      expect(tiles.fold<int>(0, (n, t) => n + t.columns * t.rows), (tc * 2 + 15) * (tr + 20));
    });

    test('пустая схема не даёт страниц', () {
      expect(a4.tiles(columns: 0, rows: 10), isEmpty);
    });

    test('страниц больше на листы легенды: 120 цветов = 2 листа по 2 колонки', () {
      expect(LegendLayout.pageCount(0), 0);
      expect(LegendLayout.pageCount(1), 1);
      expect(LegendLayout.pageCount(LegendLayout.rowsPerPage), 1);
      expect(LegendLayout.pageCount(LegendLayout.rowsPerPage + 1), 2);
      expect(a4.pageCount(columns: 10, rows: 10, colors: 3), 2);
    });

    test('подписи на границах, кратных 10, с абсолютными номерами', () {
      expect(PrintLayout.majorLines(0, 40), <int>[0, 10, 20, 30, 40]);
      expect(PrintLayout.majorLines(215, 255), <int>[220, 230, 240, 250]);
      expect(PrintLayout.majorLines(81, 89), isEmpty);
    });
  });

  group('PrintOptions', () {
    test('номера мест: одна стойка — просто номер, больше — «стойка-место»', () {
      const PrintOptions options = PrintOptions();
      expect(options.slotLabel(0, 30), '1');
      expect(options.slotLabel(29, 30), '30');
      expect(options.slotLabel(0, 70), '1-1');
      expect(options.slotLabel(49, 70), '1-50');
      expect(options.slotLabel(50, 70), '2-1');
      expect(const PrintOptions(slotsPerRack: 80).slotLabel(79, 80), '80');
    });

    test('сохранение: туда и обратно, мусор даёт значения по умолчанию, места ограничены', () {
      const PrintOptions options = PrintOptions(paper: PrintPaper.a2, slotsPerRack: 80);
      expect(PrintOptions.decode(options.encode()), options);
      expect(PrintOptions.decode(null), const PrintOptions());
      expect(PrintOptions.decode('a9:x'), const PrintOptions());
      expect(PrintOptions.decode('a3:5000').slotsPerRack, PrintOptions.maxSlots);
      expect(PrintOptions.decode('zz:60').paper, PrintPaper.a4);
    });
  });
}
