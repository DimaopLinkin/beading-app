import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/fabric.dart';
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
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';
import 'package:beading/presentation/editor/editor_cubit.dart';
import 'package:beading/presentation/editor/editor_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';

PatternColor _thread(String code, String name, Rgb rgb) => PatternColor(
  rgb: rgb,
  name: name,
  components: <CatalogRef>[CatalogRef(brand: 'Гамма', code: code)],
);

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late EditorCubit cubit;

  GridPattern pattern({StitchLayers? layers}) => GridPattern(
    id: 'pat-1',
    projectId: 'proj-1',
    geometry: const RectangularGeometry(),
    metrics: Fabric.standard,
    grid: Grid.empty(width: 4, height: 3),
    palette: PaletteSnapshot(<PatternColor>[
      _thread('3071', 'Красный', const Rgb(200, 0, 0)),
      _thread('3095', 'Синий', const Rgb(0, 0, 200)),
    ]),
    layers: layers == null ? null : StitchLayersCodec.toBlob(layers),
  );

  Future<void> start({GridPattern? initial, CatalogRepository? catalog}) async {
    projects.projects['proj-1'] = Project(
      id: 'proj-1',
      name: 'Котик',
      status: ProjectStatus.idea,
      craft: Craft.crossStitch,
      technique: Technique.defaultFor(Craft.crossStitch),
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
      catalog: catalog,
      saveDelay: const Duration(milliseconds: 20),
    );
    await cubit.load();
  }

  setUp(() {
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
  });

  tearDown(() => cubit.close());

  StitchLayers layers() => cubit.state.layers!;

  test('вышивка открывается со слоями; у бисерной схемы слоёв нет', () async {
    await start();

    expect(cubit.state.isStitch, isTrue);
    expect(layers().isEmpty, isTrue);
    expect(layers().columns, 4);
  });

  test('сохранённые слои читаются при открытии', () async {
    final StitchLayers saved = StitchLayers(
      columns: 4,
      rows: 3,
      lines: <LineStitch>[
        LineStitch(a: const LatticeNode(0, 0), b: const LatticeNode(2, 0), kind: LineKind.backstitch, color: 1),
      ],
    );
    await start(initial: pattern(layers: saved));

    expect(layers().lines, hasLength(1));
  });

  group('неполные крестики', () {
    test('полукрестик берёт ближайшую к касанию диагональ', () async {
      await start();
      cubit.selectTool(EditorTool.halfStitch);

      cubit.tapPoint(const Offset(1.2, 0.2)); // верхний левый угол — диагональ `\`
      cubit.tapPoint(const Offset(2.8, 0.2)); // верхний правый угол — диагональ `/`

      expect(layers().partials.map((p) => (p.column, p.orientation)), <(int, StitchOrientation)>[
        (1, StitchOrientation.backslash),
        (2, StitchOrientation.slash),
      ]);
    });

    test('четверть, ¾ и петит — у ближайшего угла, повторное касание убирает', () async {
      await start();
      cubit.selectTool(EditorTool.quarterStitch);
      cubit.tapPoint(const Offset(0.9, 1.9));
      expect(layers().partials.single.orientation, StitchOrientation.bottomRight);
      cubit.tapPoint(const Offset(0.9, 1.9));
      expect(layers().partials, isEmpty);

      cubit.selectTool(EditorTool.threeQuarterStitch);
      cubit.tapPoint(const Offset(0.1, 0.1));
      expect(layers().partials.single.kind, PartialKind.threeQuarter);

      cubit.selectTool(EditorTool.petit);
      cubit.tapPoint(const Offset(0.1, 0.9));
      expect(layers().partials.map((p) => p.kind), contains(PartialKind.petit));
    });

    test('цвет нитки — текущий цвет палитры', () async {
      await start();
      cubit.selectColor(2);
      cubit.selectTool(EditorTool.halfStitch);

      cubit.tapPoint(const Offset(0.2, 0.2));

      expect(layers().partials.single.color, 2);
    });

    test('без цвета в палитре — подсказка, стежок не ставится', () async {
      await start(initial: pattern().copyWith(palette: PaletteSnapshot.empty()));
      cubit.selectTool(EditorTool.halfStitch);

      cubit.tapPoint(const Offset(0.2, 0.2));

      expect(cubit.state.problem, EditorProblem.noColor);
      expect(layers().partials, isEmpty);
    });
  });

  group('бэкстич', () {
    test('касания узлов тянут ломаную; повторное касание конца заканчивает её', () async {
      await start();
      cubit.selectTool(EditorTool.backstitch);

      cubit.tapPoint(const Offset(0.1, 0.1)); // узел (0, 0)
      expect(cubit.state.lineAnchor, const LatticeNode(0, 0));
      cubit.tapPoint(const Offset(1.9, 0.1)); // узел (4, 0)
      cubit.tapPoint(const Offset(1.9, 1.1)); // узел (4, 2)

      expect(layers().lines.map((l) => (l.from, l.to)), <(LatticeNode, LatticeNode)>[
        (const LatticeNode(0, 0), const LatticeNode(4, 0)),
        (const LatticeNode(4, 0), const LatticeNode(4, 2)),
      ]);
      cubit.tapPoint(const Offset(1.9, 1.1));
      expect(cubit.state.lineAnchor, isNull);
    });

    test('протяжка ставит один отрезок между ближайшими узлами', () async {
      await start();
      cubit.selectTool(EditorTool.backstitch);

      cubit.dragLine(const Offset(0.4, 0.6), const Offset(2.1, 0.4));

      // 0,4 · 2 → 1; 0,6 · 2 → 1; 2,1 · 2 → 4; 0,4 · 2 → 1.
      expect(layers().lines.single.from, const LatticeNode(1, 1));
      expect(layers().lines.single.to, const LatticeNode(4, 1));
    });

    test('смена инструмента сбрасывает начало ломаной', () async {
      await start();
      cubit.selectTool(EditorTool.backstitch);
      cubit.tapPoint(const Offset(0.1, 0.1));

      cubit.selectTool(EditorTool.knot);

      expect(cubit.state.lineAnchor, isNull);
    });
  });

  test('узелок ставится в ближайший узел и убирается повторным касанием', () async {
    await start();
    cubit.selectTool(EditorTool.knot);

    cubit.tapPoint(const Offset(1.45, 1.55));
    expect(layers().points.single.node, const LatticeNode(3, 3));
    cubit.tapPoint(const Offset(1.45, 1.55));

    expect(layers().points, isEmpty);
  });

  group('ластик', () {
    test('касание рядом с линией убирает линию, а не клетку', () async {
      await start();
      cubit.selectTool(EditorTool.brush);
      cubit.tapCell(const CellPosition(0, 0));
      cubit.selectTool(EditorTool.backstitch);
      cubit.dragLine(Offset.zero, const Offset(2, 0));
      cubit.selectTool(EditorTool.eraser);

      cubit.tapPoint(const Offset(1, 0.1));

      expect(layers().lines, isEmpty);
      expect(cubit.state.pattern!.grid.at(0, 0), 1);
    });

    test('касание в клетке убирает крестик и неполные стежки клетки', () async {
      await start();
      cubit.tapCell(const CellPosition(1, 1));
      cubit.selectTool(EditorTool.halfStitch);
      cubit.tapPoint(const Offset(1.2, 1.2));
      cubit.selectTool(EditorTool.eraser);

      cubit.tapPoint(const Offset(1.5, 1.5));

      expect(cubit.state.pattern!.grid.at(1, 1), 0);
      expect(layers().partials, isEmpty);
    });

    test('мазок ластика убирает и неполные стежки в проведённых клетках', () async {
      await start();
      cubit.selectTool(EditorTool.halfStitch);
      cubit.tapPoint(const Offset(1.2, 1.2));
      cubit.selectTool(EditorTool.eraser);

      cubit.beginStroke();
      cubit.strokeTo(const CellPosition(1, 1));
      cubit.endStroke();

      expect(layers().partials, isEmpty);
    });
  });

  test('отмена возвращает и крестики, и слои одним шагом', () async {
    await start();
    cubit.selectTool(EditorTool.halfStitch);
    cubit.tapPoint(const Offset(1.2, 1.2));
    cubit.selectTool(EditorTool.knot);
    cubit.tapPoint(const Offset(2.5, 1.5));

    cubit.undo();
    expect(layers().points, isEmpty);
    expect(layers().partials, hasLength(1));
    cubit.undo();
    expect(layers().partials, isEmpty);
    cubit.redo();
    expect(layers().partials, hasLength(1));
  });

  test('зеркало отражает слои вместе с крестиками, выделение не мешает', () async {
    await start();
    cubit.selectTool(EditorTool.brush);
    cubit.tapCell(const CellPosition(0, 0));
    cubit.selectTool(EditorTool.knot);
    cubit.tapPoint(const Offset(0.5, 0.5));
    cubit.selectRect(const CellPosition(0, 0), const CellPosition(1, 1));

    cubit.mirrorHorizontal();

    expect(cubit.state.pattern!.grid.at(3, 0), 1);
    expect(layers().points.single.node, const LatticeNode(7, 1));
  });

  test('вставка ряда сдвигает стежки; удаление цвета чистит слои', () async {
    await start();
    cubit.selectTool(EditorTool.halfStitch);
    cubit.tapPoint(const Offset(1.2, 1.2));

    cubit.insertRow(0);
    expect(layers().partials.single.row, 2);
    expect(layers().rows, 4);

    cubit.removeColor(1);
    expect(layers().partials, isEmpty);
    expect(cubit.state.canUndo, isFalse);
  });

  test('слои сохраняются вместе со схемой', () async {
    await start();
    cubit.selectTool(EditorTool.knot);
    cubit.tapPoint(const Offset(0.5, 0.5));

    await cubit.flush();

    final StitchLayers saved = StitchLayersCodec.fromBlob(patterns.byProject['proj-1']!.layers!).valueOrNull!;
    expect(saved.points, hasLength(1));
  });

  group('бусина', () {
    const CatalogRef ref = CatalogRef(brand: 'Miyuki', code: 'DB0010');

    test('без выбранной бусины — подсказка; выбранная ставится в узел и убирается повторным касанием', () async {
      await start();
      cubit.selectTool(EditorTool.bead);

      cubit.tapPoint(const Offset(1.1, 1.1));
      expect(cubit.state.problem, EditorProblem.noBead);
      expect(layers().points, isEmpty);

      cubit.selectBead(ref, const Rgb(200, 10, 20));
      cubit.tapPoint(const Offset(1.1, 1.1));
      expect(layers().points.single.bead, ref);
      expect(layers().points.single.node, const LatticeNode(2, 2));
      expect(cubit.state.beadColors[ref], const Rgb(200, 10, 20));
      cubit.tapPoint(const Offset(1.1, 1.1));
      expect(layers().points, isEmpty);
    });

    test('цвета бусин сохранённых слоёв находятся по каталогу при открытии', () async {
      final StitchLayers saved = StitchLayers(
        columns: 4,
        rows: 3,
        points: <PointStitch>[PointStitch.bead(node: const LatticeNode(2, 2), bead: ref)],
      );

      await start(
        initial: pattern(layers: saved),
        catalog: FakeCatalogRepository(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.beadColors[ref], FakeCatalogRepository.red.rgb);
    });
  });
}
