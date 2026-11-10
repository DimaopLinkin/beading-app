import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/editor/editor_commands.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

CellPosition _p(int c, int r) => CellPosition(c, r);

/// Сетка из строк-рядов, символы — индексы палитры (`.` = 0).
Grid _g(List<String> rows) => Grid.fromCells(
  width: rows.first.length,
  height: rows.length,
  cells: <int>[
    for (final String row in rows)
      for (final int ch in row.codeUnits) ch == 0x2E ? 0 : ch - 0x30,
  ],
);

List<String> _rows(Grid g) => <String>[
  for (int r = 0; r < g.height; r++)
    <String>[for (int c = 0; c < g.width; c++) g.at(c, r) == 0 ? '.' : '${g.at(c, r)}'].join(),
];

Grid _ok(Result<Grid> r) => (r as Success<Grid>).value;

const Map<String, GridGeometry> _geometries = <String, GridGeometry>{
  'rectangular': GridGeometry.rectangular(),
  'peyote': GridGeometry.peyote(),
  'peyote drop2': GridGeometry.peyote(drop: 2),
  'brick': GridGeometry.brick(),
};

void main() {
  group('кисть и ластик', () {
    test('красит ячейки мазком и не меняет исходную сетку', () {
      final Grid g = Grid.empty(width: 3, height: 2);
      final Grid out = EditorCommands.paint(g, <CellPosition>[_p(0, 0), _p(2, 1)], 5);
      expect(_rows(out), <String>['5..', '..5']);
      expect(_rows(g), <String>['...', '...']);
    });

    test('ячейки вне сетки пропускаются, без изменений возвращается та же сетка', () {
      final Grid g = Grid.empty(width: 2, height: 2);
      expect(identical(EditorCommands.paint(g, <CellPosition>[_p(5, 5), _p(-1, 0)], 3), g), isTrue);
      expect(identical(EditorCommands.paint(g, <CellPosition>[_p(0, 0)], 0), g), isTrue);
    });

    test('выделение ограничивает кисть', () {
      final Grid g = Grid.empty(width: 3, height: 1);
      final Grid out = EditorCommands.paint(
        g,
        <CellPosition>[_p(0, 0), _p(1, 0)],
        4,
        within: const CellRect(left: 1, top: 0, width: 1, height: 1),
      );
      expect(_rows(out), <String>['.4.']);
    });

    test('ластик очищает', () {
      expect(_rows(EditorCommands.erase(_g(<String>['123']), <CellPosition>[_p(1, 0)])), <String>['1.3']);
    });

    test('недопустимое значение — ошибка', () {
      expect(
        () => EditorCommands.paint(Grid.empty(width: 1, height: 1), <CellPosition>[_p(0, 0)], 70000),
        throwsArgumentError,
      );
    });
  });

  test('пипетка', () {
    final Grid g = _g(<String>['12']);
    expect(EditorCommands.pick(g, _p(1, 0)), 2);
    expect(EditorCommands.pick(g, _p(2, 0)), isNull);
  });

  group('заливка', () {
    test('прямоугольная: не протекает через диагональ', () {
      final Grid g = _g(<String>['.1.', '1..', '...']);
      final Grid out = EditorCommands.floodFill(g, const GridGeometry.rectangular(), _p(0, 0), 7);
      expect(_rows(out), <String>['71.', '1..', '...']);
    });

    test('прямоугольная: заливает связную область', () {
      final Grid g = _g(<String>['..1', '.11', '...']);
      final Grid out = EditorCommands.floodFill(g, const GridGeometry.rectangular(), _p(0, 0), 7);
      expect(_rows(out), <String>['771', '711', '777']);
    });

    test('peyote: сдвинутый столбец соединяет то, что в прямоугольной сетке лишь касается углом', () {
      // Столбец 1 сдвинут вниз на ½ ячейки: (0,1) граничит с (1,0) и (1,1).
      final Grid g = _g(<String>['1.', '.1']);
      expect(_rows(EditorCommands.floodFill(g, const GridGeometry.peyote(), _p(0, 1), 7)), <String>['17', '71']);
      expect(_rows(EditorCommands.floodFill(g, const GridGeometry.rectangular(), _p(0, 1), 7)), <String>['1.', '71']);
    });

    test('peyote: (0,0) касается только (1,0), а не (1,1)', () {
      final Grid g = _g(<String>['..', '1.']);
      final Grid out = EditorCommands.floodFill(g, const GridGeometry.peyote(), _p(0, 0), 7);
      expect(_rows(out), <String>['77', '17']);
    });

    test('peyote drop 2: столбцы 0–1 и 2–3 сдвинуты группами', () {
      // Столбцы 2–3 сдвинуты вниз: (1,1) граничит с (2,0) и (2,1).
      final Grid g = _g(<String>['11..', '1.11']);
      // (1,1) пуста, соседи (2,0) и (2,1): (2,0)=. — путь в (3,0).
      expect(_rows(EditorCommands.floodFill(g, const GridGeometry.peyote(drop: 2), _p(1, 1), 7)), <String>[
        '1177',
        '1711',
      ]);
    });

    test('brick: ряд 1 сдвинут вправо на ½, диагональ соединяется', () {
      final Grid g = _g(<String>['1.', '.1']);
      expect(_rows(EditorCommands.floodFill(g, const GridGeometry.brick(), _p(0, 1), 7)), <String>['17', '71']);
    });

    test('то же значение, старт вне сетки или вне выделения — без изменений', () {
      final Grid g = _g(<String>['11']);
      const GridGeometry geo = GridGeometry.rectangular();
      expect(identical(EditorCommands.floodFill(g, geo, _p(0, 0), 1), g), isTrue);
      expect(identical(EditorCommands.floodFill(g, geo, _p(9, 0), 2), g), isTrue);
      expect(
        identical(
          EditorCommands.floodFill(g, geo, _p(0, 0), 2, within: const CellRect(left: 1, top: 0, width: 1, height: 1)),
          g,
        ),
        isTrue,
      );
    });

    test('выделение ограничивает заливку', () {
      final Grid g = Grid.empty(width: 4, height: 1);
      final Grid out = EditorCommands.floodFill(
        g,
        const GridGeometry.rectangular(),
        _p(1, 0),
        3,
        within: const CellRect(left: 1, top: 0, width: 2, height: 1),
      );
      expect(_rows(out), <String>['.33.']);
    });

    for (final MapEntry<String, GridGeometry> e in _geometries.entries) {
      test('${e.key}: заливка пустой сетки закрашивает всё', () {
        final Grid out = EditorCommands.floodFill(Grid.empty(width: 5, height: 4), e.value, _p(2, 1), 9);
        expect(out.cells.every((v) => v == 9), isTrue);
      });
    }
  });

  group('замена и обмен цветов', () {
    test('замена во всей сетке и в выделении', () {
      final Grid g = _g(<String>['121', '212']);
      expect(_rows(EditorCommands.replaceColor(g, 1, 3)), <String>['323', '232']);
      expect(
        _rows(EditorCommands.replaceColor(g, 1, 3, within: const CellRect(left: 0, top: 0, width: 2, height: 1))),
        <String>['321', '212'],
      );
    });

    test('обмен двух цветов', () {
      final Grid g = _g(<String>['12.', '.21']);
      expect(_rows(EditorCommands.swapColors(g, 1, 2)), <String>['21.', '.12']);
      expect(
        _rows(EditorCommands.swapColors(g, 1, 2, within: const CellRect(left: 0, top: 1, width: 3, height: 1))),
        <String>['12.', '.12'],
      );
    });

    test('нечего менять — та же сетка; область вне сетки — та же сетка', () {
      final Grid g = _g(<String>['12']);
      expect(identical(EditorCommands.replaceColor(g, 5, 6), g), isTrue);
      expect(identical(EditorCommands.replaceColor(g, 1, 1), g), isTrue);
      expect(identical(EditorCommands.swapColors(g, 1, 1), g), isTrue);
      expect(identical(EditorCommands.swapColors(g, 8, 9), g), isTrue);
      expect(
        identical(
          EditorCommands.replaceColor(g, 1, 3, within: const CellRect(left: 5, top: 5, width: 1, height: 1)),
          g,
        ),
        isTrue,
      );
    });
  });

  group('зеркало', () {
    final Grid g = _g(<String>['123', '456']);

    test('по горизонтали и вертикали для всей сетки', () {
      expect(_rows(EditorCommands.mirrorHorizontal(g)), <String>['321', '654']);
      expect(_rows(EditorCommands.mirrorVertical(g)), <String>['456', '123']);
    });

    test('внутри выделения', () {
      const CellRect r = CellRect(left: 0, top: 0, width: 2, height: 2);
      expect(_rows(EditorCommands.mirrorHorizontal(g, within: r)), <String>['213', '546']);
      expect(_rows(EditorCommands.mirrorVertical(g, within: r)), <String>['453', '126']);
    });

    test('выделение обрезается по сетке; вне сетки — без изменений', () {
      expect(
        _rows(EditorCommands.mirrorHorizontal(g, within: const CellRect(left: 1, top: 0, width: 9, height: 1))),
        <String>['132', '456'],
      );
      expect(
        identical(EditorCommands.mirrorVertical(g, within: const CellRect(left: 9, top: 9, width: 1, height: 1)), g),
        isTrue,
      );
    });

    test('двойное зеркало возвращает исходное', () {
      expect(EditorCommands.mirrorHorizontal(EditorCommands.mirrorHorizontal(g)), g);
      expect(EditorCommands.mirrorVertical(EditorCommands.mirrorVertical(g)), g);
    });
  });

  group('ряды и столбцы', () {
    final Grid g = _g(<String>['12', '34']);

    test('вставка ряда в начало, середину, конец, с заливкой', () {
      expect(_rows(_ok(EditorCommands.insertRow(g, 0))), <String>['..', '12', '34']);
      expect(_rows(_ok(EditorCommands.insertRow(g, 1, fill: 9))), <String>['12', '99', '34']);
      expect(_rows(_ok(EditorCommands.insertRow(g, 2))), <String>['12', '34', '..']);
    });

    test('удаление ряда', () {
      expect(_rows(_ok(EditorCommands.deleteRow(g, 0))), <String>['34']);
      expect(_rows(_ok(EditorCommands.deleteRow(g, 1))), <String>['12']);
    });

    test('вставка и удаление столбца', () {
      expect(_rows(_ok(EditorCommands.insertColumn(g, 0))), <String>['.12', '.34']);
      expect(_rows(_ok(EditorCommands.insertColumn(g, 1, fill: 7))), <String>['172', '374']);
      expect(_rows(_ok(EditorCommands.insertColumn(g, 2))), <String>['12.', '34.']);
      expect(_rows(_ok(EditorCommands.deleteColumn(g, 0))), <String>['2', '4']);
      expect(_rows(_ok(EditorCommands.deleteColumn(g, 1))), <String>['1', '3']);
    });

    test('отказы: позиция вне диапазона, последний ряд/столбец, предел размера', () {
      expect(EditorCommands.insertRow(g, 3).failureOrNull, isA<ValidationFailure>());
      expect(EditorCommands.insertRow(g, -1).failureOrNull, isA<ValidationFailure>());
      expect(EditorCommands.insertColumn(g, 3).failureOrNull, isA<ValidationFailure>());
      expect(EditorCommands.deleteRow(g, 2).failureOrNull, isA<ValidationFailure>());
      expect(EditorCommands.deleteColumn(g, -1).failureOrNull, isA<ValidationFailure>());
      final Grid one = _g(<String>['1']);
      expect(EditorCommands.deleteRow(one, 0).failureOrNull, isA<ValidationFailure>());
      expect(EditorCommands.deleteColumn(one, 0).failureOrNull, isA<ValidationFailure>());
      final Grid tall = Grid.empty(width: 1, height: Grid.maxSide);
      expect(EditorCommands.insertRow(tall, 0).failureOrNull, isA<ValidationFailure>());
      final Grid wide = Grid.empty(width: Grid.maxSide, height: 1);
      expect(EditorCommands.insertColumn(wide, 0).failureOrNull, isA<ValidationFailure>());
    });

    test('вставка потом удаление возвращает исходную сетку', () {
      expect(_ok(EditorCommands.deleteRow(_ok(EditorCommands.insertRow(g, 1)), 1)), g);
      expect(_ok(EditorCommands.deleteColumn(_ok(EditorCommands.insertColumn(g, 1)), 1)), g);
    });
  });

  group('изменение размера', () {
    final Grid g = _g(<String>['123', '456', '789']);

    test('расширение прижато к верхнему левому', () {
      expect(_rows(_ok(EditorCommands.resize(_g(<String>['12']), width: 3, height: 2))), <String>['12.', '...']);
    });

    test('обрезка по разным якорям', () {
      expect(_rows(_ok(EditorCommands.resize(g, width: 2, height: 2))), <String>['12', '45']);
      expect(_rows(_ok(EditorCommands.resize(g, width: 2, height: 2, anchor: ResizeAnchor.bottomRight))), <String>[
        '56',
        '89',
      ]);
      expect(_rows(_ok(EditorCommands.resize(g, width: 1, height: 1, anchor: ResizeAnchor.center))), <String>['5']);
      expect(_rows(_ok(EditorCommands.resize(g, width: 2, height: 2, anchor: ResizeAnchor.topRight))), <String>[
        '23',
        '56',
      ]);
      expect(_rows(_ok(EditorCommands.resize(g, width: 2, height: 2, anchor: ResizeAnchor.bottomLeft))), <String>[
        '45',
        '78',
      ]);
      expect(_rows(_ok(EditorCommands.resize(g, width: 1, height: 3, anchor: ResizeAnchor.top))), <String>[
        '2',
        '5',
        '8',
      ]);
      expect(_rows(_ok(EditorCommands.resize(g, width: 3, height: 1, anchor: ResizeAnchor.left))), <String>['456']);
      expect(_rows(_ok(EditorCommands.resize(g, width: 3, height: 1, anchor: ResizeAnchor.right))), <String>['456']);
      expect(_rows(_ok(EditorCommands.resize(g, width: 1, height: 3, anchor: ResizeAnchor.bottom))), <String>[
        '2',
        '5',
        '8',
      ]);
    });

    test('расширение по центру', () {
      expect(
        _rows(_ok(EditorCommands.resize(_g(<String>['1']), width: 3, height: 3, anchor: ResizeAnchor.center))),
        <String>['...', '.1.', '...'],
      );
    });

    test('недопустимый размер — отказ', () {
      expect(EditorCommands.resize(g, width: 0, height: 1).failureOrNull, isA<ValidationFailure>());
      expect(EditorCommands.resize(g, width: 1, height: Grid.maxSide + 1).failureOrNull, isA<ValidationFailure>());
    });
  });

  group('все геометрии: структурные команды не зависят от раскладки', () {
    for (final MapEntry<String, GridGeometry> e in _geometries.entries) {
      test('${e.key}: цикл вставка/удаление и зеркало-инволюция', () {
        final Grid g = _g(<String>['1.2', '.3.', '4.5']);
        expect(_ok(EditorCommands.deleteColumn(_ok(EditorCommands.insertColumn(g, 1)), 1)), g);
        expect(EditorCommands.mirrorVertical(EditorCommands.mirrorVertical(g)), g);
        final Grid filled = EditorCommands.floodFill(g, e.value, _p(1, 1), 8);
        expect(filled.at(1, 1), 8);
      });
    }
  });

  test('CellRect: углы в любом порядке, содержит, обрезка', () {
    final CellRect r = CellRect.fromCorners(_p(3, 4), _p(1, 2));
    expect(r, const CellRect(left: 1, top: 2, width: 3, height: 3));
    expect(r.contains(_p(3, 4)), isTrue);
    expect(r.contains(_p(4, 4)), isFalse);
    expect(r.toString(), contains('3×3'));
    expect(CellRect.all(_g(<String>['12', '34'])), const CellRect(left: 0, top: 0, width: 2, height: 2));
    expect(
      const CellRect(left: -2, top: -2, width: 3, height: 3).clipTo(_g(<String>['12', '34'])),
      const CellRect(left: 0, top: 0, width: 1, height: 1),
    );
    expect(const CellRect(left: 5, top: 0, width: 1, height: 1).clipTo(_g(<String>['12'])), isNull);
  });
}
