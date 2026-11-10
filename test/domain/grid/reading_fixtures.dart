import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/word_chart.dart';

/// Эталонная схема для тестов порядка плетения: рисунок буквами, `.` — пустая ячейка.
///
/// Рисунки составлены вручную; ожидаемый word chart каждого ряда выписан с рисунка вручную, а не получен из кода.
/// Буква `A` — цвет 1, `B` — 2, `C` — 3.
final class ReadingFixture {
  const ReadingFixture(this.name, this.rows);

  final String name;

  /// Ряды сетки сверху вниз.
  final List<String> rows;

  int get width => rows.first.length;
  int get height => rows.length;

  Grid get grid => Grid.fromCells(
    width: width,
    height: height,
    cells: <int>[
      for (final String row in rows)
        for (final String ch in row.split('')) ch == '.' ? 0 : ch.codeUnitAt(0) - 0x40,
    ],
  );
}

/// Станок, 6 × 4.
const ReadingFixture loomFixture = ReadingFixture('станок', <String>['AABBBA', 'ABBBBC', 'AAAAAA', 'CAAAAB']);

/// Кирпичный стежок, 5 × 4.
const ReadingFixture brickFixture = ReadingFixture('кирпичный', <String>['ABABA', 'BBAAA', 'AABBC', 'CCCAB']);

/// Мозаика с чётным числом бусин в первом проходе: 4 столбца по 3 бусины.
const ReadingFixture peyoteEvenFixture = ReadingFixture('пейот чётный', <String>['AABB', 'BABA', 'CCAA']);

/// Нечётная мозаика: второй столбец на одну бусину короче первого (пустая ячейка в конце).
const ReadingFixture peyoteOddFixture = ReadingFixture('пейот нечётный', <String>['AABB', 'BABA', 'C.AA']);

/// Серии ряда строкой: «2A 1B».
String describeRuns(List<WordRun> runs) => runs.map((r) => '${r.count}${_letter(r.colorIndex)}').join(' ');

String _letter(int colorIndex) => String.fromCharCode(0x40 + colorIndex);
