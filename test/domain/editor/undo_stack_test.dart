import 'package:beading/domain/editor/editor_commands.dart';
import 'package:beading/domain/editor/undo_stack.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:flutter_test/flutter_test.dart';

Grid _empty() => Grid.empty(width: 4, height: 1);

Grid _paint(Grid g, int column, int value) => EditorCommands.paint(g, <CellPosition>[CellPosition(column, 0)], value);

void main() {
  test('undo и redo восстанавливают точное состояние', () {
    final Grid start = _empty();
    final UndoStack stack = UndoStack(start);
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
    final UndoStack stack = UndoStack(start);
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
    final UndoStack stack = UndoStack(start)..beginGroup();
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
    final UndoStack stack = UndoStack(start)
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
    final UndoStack stack = UndoStack(start)
      ..beginGroup()
      ..apply(_paint(start, 0, 1));
    expect(stack.undo(), start);
    expect(stack.isGrouping, isFalse);
  });

  test('лимит шагов: старые отбрасываются', () {
    final UndoStack stack = UndoStack(_empty(), limit: 3);
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
    final UndoStack stack = UndoStack(_empty());
    Grid g = _empty();
    for (int i = 1; i <= 150; i++) {
      g = _paint(g, 0, i);
      stack.apply(g);
    }
    expect(stack.undoDepth, 100);
  });

  test('бюджет памяти: история большой схемы короче лимита, текущее состояние цело', () {
    final UndoStack stack = UndoStack(_empty(), maxTotalCells: 8);
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
    final UndoStack stack = UndoStack(start)..apply(_paint(start, 0, 1));
    stack.undo();
    stack.clear();
    expect(stack.canUndo, isFalse);
    expect(stack.canRedo, isFalse);
  });
}
