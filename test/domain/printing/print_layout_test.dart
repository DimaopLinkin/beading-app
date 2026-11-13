import 'package:beading/domain/printing/print_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('клетка 3 мм: 10 крестиков = 3 см', () {
    expect(PrintLayout.cellPx * 10, 3 * 10 * PrintLayout.pixelsPerMm);
    expect(PrintLayout.pageWidthPx, (PrintLayout.pageWidthMm * PrintLayout.pixelsPerMm).round());
    expect(PrintLayout.pageHeightPx, (PrintLayout.pageHeightMm * PrintLayout.pixelsPerMm).round());
  });

  test('сетка, подписи и легенда помещаются на лист', () {
    const int gridRight = PrintLayout.gridLeftPx + PrintLayout.tileColumns * PrintLayout.cellPx + PrintLayout.axisPx;
    expect(gridRight, lessThan(PrintLayout.legendLeftPx));
    expect(PrintLayout.legendLeftPx + PrintLayout.legendWidthPx, PrintLayout.pageWidthPx - PrintLayout.marginPx);
    const int gridBottom = PrintLayout.gridTopPx + PrintLayout.tileRows * PrintLayout.cellPx + PrintLayout.axisPx;
    expect(gridBottom + PrintLayout.footerPx, lessThanOrEqualTo(PrintLayout.pageHeightPx - PrintLayout.marginPx));
  });

  test('нарезка: страницы 40×80 по строкам, края короче', () {
    final tiles = PrintLayout.tiles(columns: 95, rows: 100);
    expect(tiles, hasLength(6));
    expect(tiles.first, const PrintTile(column: 0, row: 0, columns: 40, rows: 80));
    expect(tiles[2], const PrintTile(column: 80, row: 0, columns: 15, rows: 80));
    expect(tiles.last, const PrintTile(column: 80, row: 80, columns: 15, rows: 20));
    expect(tiles.fold<int>(0, (n, t) => n + t.columns * t.rows), 95 * 100);
  });

  test('пустая схема не даёт страниц', () {
    expect(PrintLayout.tiles(columns: 0, rows: 10), isEmpty);
  });

  test('подписи на границах, кратных 10, с абсолютными номерами', () {
    expect(PrintLayout.majorLines(0, 40), <int>[0, 10, 20, 30, 40]);
    expect(PrintLayout.majorLines(215, 255), <int>[220, 230, 240, 250]);
    expect(PrintLayout.majorLines(81, 89), isEmpty);
  });
}
