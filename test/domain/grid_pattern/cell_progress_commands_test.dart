import 'package:beading/core/failure.dart';
import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/domain/grid_pattern/use_cases/cell_progress_commands.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grid_pattern.dart';

void main() {
  late FakeGridPatternRepository patterns;
  late FakeCellProgressStore store;

  // Схема 4×3: ряды [1,2,0,1], [2,2,1,0], [0,1,1,2].
  setUp(() {
    patterns = FakeGridPatternRepository()..byProject['proj-1'] = sampleGridPattern();
    store = FakeCellProgressStore();
  });

  Future<CellProgress> state() async => (await store.load('pat-1')).valueOrNull!;

  test('MarkCells отмечает клетки, MarkCells(done: false) снимает', () async {
    final MarkCells mark = MarkCells(patterns: patterns, progress: store);
    await mark(projectId: 'proj-1', cells: const <CellPosition>[CellPosition(0, 0), CellPosition(1, 0)], done: true);
    expect((await state()).count, 2);
    await mark(projectId: 'proj-1', cells: const <CellPosition>[CellPosition(0, 0)], done: false);
    expect((await state()).isDone(0, 0), isFalse);
    expect((await state()).isDone(1, 0), isTrue);
  });

  test('пустые клетки схемы не отмечаются; без изменений ничего не пишется', () async {
    final MarkCells mark = MarkCells(patterns: patterns, progress: store);
    final result = await mark(projectId: 'proj-1', cells: const <CellPosition>[CellPosition(2, 0)], done: true);
    expect(result.isSuccess, isTrue);
    expect(store.calls, isEmpty);
    await mark(projectId: 'proj-1', cells: const <CellPosition>[CellPosition(0, 0)], done: true);
    await mark(projectId: 'proj-1', cells: const <CellPosition>[CellPosition(0, 0)], done: true);
    expect(store.calls, hasLength(1), reason: 'повторная отметка блок не переписывает');
  });

  test('клетка вне схемы и неизвестный проект — ошибки', () async {
    final MarkCells mark = MarkCells(patterns: patterns, progress: store);
    expect(
      (await mark(projectId: 'proj-1', cells: const <CellPosition>[CellPosition(4, 0)], done: true)).failureOrNull,
      isA<ValidationFailure>(),
    );
    expect(
      (await mark(projectId: 'нет', cells: const <CellPosition>[CellPosition(0, 0)], done: true)).failureOrNull,
      isA<NotFoundFailure>(),
    );
    expect(store.calls, isEmpty);
  });

  test('ошибка хранилища возвращается', () async {
    store.failNextWrite = const StorageFailure('диск');
    final result = await MarkCells(
      patterns: patterns,
      progress: store,
    )(projectId: 'proj-1', cells: const <CellPosition>[CellPosition(0, 0)], done: true);
    expect(result.failureOrNull, isA<StorageFailure>());
  });

  test('MarkRect отмечает прямоугольник, обрезая по схеме; пропускает пустые клетки', () async {
    await MarkRect(
      patterns: patterns,
      progress: store,
    )(projectId: 'proj-1', rect: const CellRect(left: 2, top: 1, width: 10, height: 10), done: true);
    // Клетки (2,1)=1, (3,1)=0 пустая, (2,2)=1, (3,2)=2.
    expect((await state()).cells().toList(), const <CellPosition>[
      CellPosition(2, 1),
      CellPosition(2, 2),
      CellPosition(3, 2),
    ]);
    final outside = await MarkRect(
      patterns: patterns,
      progress: store,
    )(projectId: 'proj-1', rect: const CellRect(left: 9, top: 9, width: 2, height: 2), done: true);
    expect(outside.failureOrNull, isA<ValidationFailure>());
  });

  test('MarkColor отмечает все клетки цвета и снимает их', () async {
    final MarkColor mark = MarkColor(patterns: patterns, progress: store);
    await mark(projectId: 'proj-1', color: 1, done: true);
    expect((await state()).count, 4, reason: 'цвет 2 в схеме встречается четыре раза');
    await mark(projectId: 'proj-1', color: 1, done: false);
    expect((await state()).isEmpty, isTrue);
    expect((await mark(projectId: 'proj-1', color: 5, done: true)).failureOrNull, isA<ValidationFailure>());
  });
}
