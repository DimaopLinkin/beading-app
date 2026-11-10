import 'package:beading/core/failure.dart';
import 'package:beading/domain/editor/cell_rect.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/save_grid_pattern.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/touch_project.dart';
import 'package:beading/presentation/editor/editor_cubit.dart';
import 'package:beading/presentation/editor/editor_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';

PatternColor _blue() => PatternColor(
  rgb: const Rgb(0, 0, 200),
  name: 'Синий',
  components: const <CatalogRef>[CatalogRef(brand: 'Miyuki Delica', code: 'DB0002')],
);

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late EditorCubit cubit;

  GridPattern pattern({int width = 5, int height = 4, GridGeometry geometry = const GridGeometry.rectangular()}) =>
      GridPattern(
        id: 'pat-1',
        projectId: 'proj-1',
        geometry: geometry,
        metrics: BeadSize.delica11,
        grid: Grid.empty(width: width, height: height),
        palette: samplePalette(),
      );

  Future<void> start({GridPattern? initial, Duration delay = const Duration(milliseconds: 50)}) async {
    projects.projects['proj-1'] = Project(
      id: 'proj-1',
      name: 'Браслет',
      status: ProjectStatus.idea,
      craft: Craft.beading,
      technique: Technique.loom,
      contentKind: ContentKind.grid,
      notes: '',
      coverPath: null,
      lastWorkedAt: DateTime.utc(2026),
    );
    patterns.byProject['proj-1'] = initial ?? pattern();
    cubit = EditorCubit(
      projectId: 'proj-1',
      projects: projects,
      patterns: patterns,
      savePattern: SaveGridPattern(patterns),
      touchProject: TouchProject(repository: projects, clock: FakeClock(DateTime.utc(2026, 2))),
      saveDelay: delay,
    );
    await cubit.load();
  }

  setUp(() {
    projects = FakeGridProjects();
    patterns = FakeGridPatternRepository();
  });

  tearDown(() async => cubit.close());

  Grid grid() => cubit.state.pattern!.grid;

  test('load: готов, первый цвет выбран, имя проекта', () async {
    await start();
    expect(cubit.state.status, EditorStatus.ready);
    expect(cubit.state.projectName, 'Браслет');
    expect(cubit.state.activeColor, 1);
  });

  test('load: нет схемы — ошибка загрузки', () async {
    projects = FakeGridProjects();
    cubit = EditorCubit(
      projectId: 'nope',
      projects: projects,
      patterns: patterns,
      savePattern: SaveGridPattern(patterns),
      touchProject: TouchProject(repository: projects, clock: FakeClock(DateTime.utc(2026))),
    );
    await cubit.load();
    expect(cubit.state.status, EditorStatus.loadFailed);
  });

  test('кисть красит ячейку цветом палитры, ластик очищает', () async {
    await start();
    cubit.tapCell(const CellPosition(1, 1));
    expect(grid().at(1, 1), 1);
    cubit.selectTool(EditorTool.eraser);
    cubit.tapCell(const CellPosition(1, 1));
    expect(grid().at(1, 1), 0);
  });

  test('мазок без пропусков и один шаг отмены', () async {
    await start(initial: pattern(width: 100, height: 4));
    cubit.beginStroke();
    cubit.strokeTo(const CellPosition(0, 0));
    cubit.strokeTo(const CellPosition(40, 0)); // быстрый скачок через 40 ячеек
    cubit.strokeTo(const CellPosition(99, 3));
    cubit.endStroke();
    for (int c = 0; c <= 40; c++) {
      expect(grid().at(c, 0), 1, reason: 'пропуск в столбце $c');
    }
    expect(cubit.state.canUndo, isTrue);
    cubit.undo();
    expect(grid().cells.every((v) => v == 0), isTrue);
    cubit.redo();
    expect(grid().at(40, 0), 1);
  });

  test('мазок на 100×400 закрашивает все ячейки вертикали', () async {
    await start(initial: pattern(width: 100, height: 400));
    cubit.beginStroke();
    cubit.strokeTo(const CellPosition(10, 0));
    cubit.strokeTo(const CellPosition(10, 399));
    cubit.endStroke();
    for (int r = 0; r < 400; r++) {
      expect(grid().at(10, r), 1);
    }
  });

  test('заливка, пипетка, замена цвета', () async {
    await start();
    cubit.selectTool(EditorTool.fill);
    cubit.tapCell(const CellPosition(0, 0));
    expect(grid().cells.every((v) => v == 1), isTrue);

    cubit.selectColor(2);
    cubit.selectTool(EditorTool.replaceColor);
    cubit.tapCell(const CellPosition(2, 2));
    expect(grid().cells.every((v) => v == 2), isTrue);

    cubit.selectTool(EditorTool.pipette);
    cubit.tapCell(const CellPosition(0, 0));
    expect(cubit.state.activeColor, 2);
    expect(cubit.state.tool, EditorTool.brush);
  });

  test('пипетка на пустой ячейке включает ластик', () async {
    await start();
    cubit.selectTool(EditorTool.pipette);
    cubit.tapCell(const CellPosition(0, 0));
    expect(cubit.state.tool, EditorTool.eraser);
  });

  test('выбор цвета после ластика возвращает кисть', () async {
    await start();
    cubit.selectTool(EditorTool.eraser);
    cubit.selectColor(2);
    expect(cubit.state.tool, EditorTool.brush);
    expect(cubit.state.activeColor, 2);
  });

  test('выделение ограничивает кисть и заливку', () async {
    await start();
    cubit.selectTool(EditorTool.selection);
    cubit.selectRect(const CellPosition(0, 0), const CellPosition(1, 1));
    expect(cubit.state.selection, const CellRect(left: 0, top: 0, width: 2, height: 2));
    cubit.selectTool(EditorTool.fill);
    cubit.selectRect(const CellPosition(0, 0), const CellPosition(1, 1));
    cubit.tapCell(const CellPosition(0, 0));
    expect(grid().at(1, 1), 1);
    expect(grid().at(2, 2), 0);
  });

  test('зеркало и вставка/удаление рядов и столбцов', () async {
    await start();
    cubit.tapCell(const CellPosition(0, 0));
    cubit.mirrorHorizontal();
    expect(grid().at(4, 0), 1);
    cubit.mirrorVertical();
    expect(grid().at(4, 3), 1);
    cubit.insertRow(0);
    expect(grid().height, 5);
    cubit.deleteRow(0);
    expect(grid().height, 4);
    cubit.insertColumn(5);
    expect(grid().width, 6);
    cubit.deleteColumn(5);
    expect(grid().width, 5);
  });

  test('последний ряд не удалить: сообщение, схема цела', () async {
    await start(initial: pattern(height: 1));
    cubit.deleteRow(0);
    expect(grid().height, 1);
    expect(cubit.state.problem, EditorProblem.lastRowOrColumn);
  });

  test('кисть без цвета: подсказка, схема цела', () async {
    await start(initial: pattern().copyWith(palette: PaletteSnapshot.empty()));
    expect(cubit.state.activeColor, 0);
    cubit.tapCell(const CellPosition(0, 0));
    expect(cubit.state.problem, EditorProblem.noColor);
    expect(grid().at(0, 0), 0);
  });

  test('палитра: добавить, изменить, удалить с переиндексацией', () async {
    await start();
    final int? value = cubit.addColor(_blue());
    expect(value, 3);
    expect(cubit.state.activeColor, 3);
    cubit.tapCell(const CellPosition(0, 0));
    cubit.selectColor(2);
    cubit.tapCell(const CellPosition(1, 0));
    cubit.updateColor(2, _blue().copyWith(name: 'Другой'));
    expect(cubit.state.pattern!.palette.colorAt(2)!.name, 'Другой');
    cubit.removeColor(2);
    expect(cubit.state.pattern!.palette.length, 2);
    expect(grid().at(0, 0), 2); // бывший цвет 3 стал 2
    expect(grid().at(1, 0), 0);
    expect(cubit.state.canUndo, isFalse);
  });

  test('автосохранение: debounce объединяет правки, потом запись', () async {
    await start(delay: const Duration(milliseconds: 30));
    cubit.tapCell(const CellPosition(0, 0));
    cubit.tapCell(const CellPosition(1, 0));
    expect(cubit.state.save, EditorSave.pending);
    expect(patterns.byProject['proj-1']!.grid.at(0, 0), 0);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(patterns.byProject['proj-1']!.grid.at(1, 0), 1);
    expect(cubit.state.save, EditorSave.saved);
  });

  test('закрытие дописывает несохранённое', () async {
    await start(delay: const Duration(seconds: 30));
    cubit.tapCell(const CellPosition(2, 2));
    await cubit.close();
    expect(patterns.byProject['proj-1']!.grid.at(2, 2), 1);
  });

  test('ошибка записи: статус failed, правка на экране, повтор записывает', () async {
    await start(delay: const Duration(milliseconds: 10));
    patterns.failNextSave = const StorageFailure('диск');
    cubit.tapCell(const CellPosition(0, 0));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(cubit.state.save, EditorSave.failed);
    expect(cubit.state.problem, EditorProblem.saveFailed);
    expect(grid().at(0, 0), 1);
    await cubit.flush();
    expect(cubit.state.save, EditorSave.saved);
    expect(patterns.byProject['proj-1']!.grid.at(0, 0), 1);
  });
}

/// Хранилище проектов без лишнего: тот же фейк (псевдоним ради читаемости).
class FakeGridProjects extends FakeProjectRepository {}
