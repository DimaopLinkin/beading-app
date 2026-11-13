import 'package:beading/domain/editor/editor_commands.dart';
import 'package:beading/domain/editor/editor_snapshot.dart';
import 'package:beading/domain/editor/undo_stack.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/stitch_layer_commands.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:flutter_test/flutter_test.dart';

Grid _empty() => Grid.empty(width: 4, height: 1);

Grid _paint(Grid g, int column, int value) => EditorCommands.paint(g, <CellPosition>[CellPosition(column, 0)], value);

void main() {
  test('undo и redo восстанавливают точное состояние', () {
    final Grid start = _empty();
    final UndoStack<Grid> stack = UndoStack<Grid>(start);
    final Grid a = _paint(start, 0, 1);
    final Grid b = _paint(a, 1, 2);
    stack
      ..apply(a)
      ..apply(b);
    expect(stack.current, b);
    expect(stack.undo(), a);
    expect(stack.undo(), start);
    expect(stack.canUndo, isFalse);
    expect(stack.undo(), isNull);
    expect(stack.redo(), a);
    expect(stack.redo(), b);
    expect(stack.canRedo, isFalse);
    expect(stack.redo(), isNull);
  });

  test('новая правка сбрасывает redo; равное состояние игнорируется', () {
    final Grid start = _empty();
    final UndoStack<Grid> stack = UndoStack<Grid>(start);
    stack.apply(_paint(start, 0, 1));
    stack.undo();
    stack.apply(start);
    expect(stack.canRedo, isTrue);
    stack.apply(_paint(start, 2, 3));
    expect(stack.canRedo, isFalse);
    expect(stack.undoDepth, 1);
  });

  test('мазок в группе — один шаг undo', () {
    final Grid start = _empty();
    final UndoStack<Grid> stack = UndoStack<Grid>(start)..beginGroup();
    expect(stack.isGrouping, isTrue);
    Grid g = start;
    for (int c = 0; c < 4; c++) {
      g = _paint(g, c, 5);
      stack.apply(g);
    }
    stack.endGroup();
    expect(stack.undoDepth, 1);
    expect(stack.undo(), start);
    expect(stack.redo(), g);
  });

  test('пустая группа ничего не записывает; следующая группа — новый шаг', () {
    final Grid start = _empty();
    final UndoStack<Grid> stack = UndoStack<Grid>(start)
      ..beginGroup()
      ..endGroup();
    expect(stack.canUndo, isFalse);
    stack
      ..beginGroup()
      ..apply(_paint(start, 0, 1))
      ..endGroup()
      ..beginGroup()
      ..apply(_paint(stack.current, 1, 1))
      ..endGroup();
    expect(stack.undoDepth, 2);
  });

  test('undo внутри открытой группы закрывает её', () {
    final Grid start = _empty();
    final UndoStack<Grid> stack = UndoStack<Grid>(start)
      ..beginGroup()
      ..apply(_paint(start, 0, 1));
    expect(stack.undo(), start);
    expect(stack.isGrouping, isFalse);
  });

  test('лимит шагов: старые отбрасываются', () {
    final UndoStack<Grid> stack = UndoStack<Grid>(_empty(), limit: 3);
    Grid g = _empty();
    for (int i = 1; i <= 5; i++) {
      g = _paint(g, 0, i);
      stack.apply(g);
    }
    expect(stack.undoDepth, 3);
    int steps = 0;
    while (stack.undo() != null) {
      steps++;
    }
    expect(steps, 3);
    expect(stack.current.at(0, 0), 2);
  });

  test('по умолчанию лимит 100', () {
    final UndoStack<Grid> stack = UndoStack<Grid>(_empty());
    Grid g = _empty();
    for (int i = 1; i <= 150; i++) {
      g = _paint(g, 0, i);
      stack.apply(g);
    }
    expect(stack.undoDepth, 100);
  });

  test('бюджет памяти: история большой схемы короче лимита, текущее состояние цело', () {
    final UndoStack<Grid> stack = UndoStack<Grid>(_empty(), maxTotalCells: 8);
    Grid g = _empty();
    for (int i = 1; i <= 10; i++) {
      g = _paint(g, 0, i);
      stack.apply(g);
    }
    expect(stack.undoDepth, 2);
    expect(stack.current, g);
  });

  test('clear забывает историю', () {
    final Grid start = _empty();
    final UndoStack<Grid> stack = UndoStack<Grid>(start)..apply(_paint(start, 0, 1));
    stack.undo();
    stack.clear();
    expect(stack.canUndo, isFalse);
    expect(stack.canRedo, isFalse);
  });

  test('вложенный beginGroup остаётся одним шагом; равное состояние в группе игнорируется', () {
    final Grid start = _empty();
    final UndoStack<Grid> stack = UndoStack<Grid>(start)
      ..beginGroup()
      ..apply(start)
      ..apply(_paint(start, 0, 1))
      ..beginGroup()
      ..apply(_paint(_paint(start, 0, 1), 1, 1));
    stack.endGroup();
    expect(stack.undoDepth, 2);
  });

  test('история снимков вышивки возвращает и сетку, и слои', () {
    final EditorSnapshot start = EditorSnapshot(grid: _empty(), layers: StitchLayers.empty(columns: 4, rows: 1));
    final UndoStack<EditorSnapshot> stack = UndoStack<EditorSnapshot>(start);
    final EditorSnapshot withLine = start.copyWith(
      layers: StitchLayerCommands.addLine(
        start.layers!,
        LineStitch(a: const LatticeNode(0, 0), b: const LatticeNode(2, 0), kind: LineKind.backstitch, color: 1),
      ),
    );

    stack.apply(withLine);
    stack.apply(withLine.copyWith(grid: _paint(withLine.grid, 0, 1)));

    expect(stack.undo(), withLine);
    expect(stack.undo(), start);
    expect(stack.canUndo, isFalse);
    expect(stack.redo(), withLine);
    // Равное состояние не пишется в историю.
    stack.apply(withLine);
    expect(stack.canRedo, isTrue);
  });
}
