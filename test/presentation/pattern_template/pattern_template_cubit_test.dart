import 'package:beading/core/failure.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/presentation/pattern_template/pattern_template_cubit.dart';
import 'package:beading/presentation/pattern_template/pattern_template_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';

void main() {
  late FakeCatalogRepository catalog;
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late FakeSettingsRepository settings;

  // Синий, кремовый, красный и серия серых для градиента.
  final List<CatalogColor> colors = <CatalogColor>[
    catalogColor('1', 'Navy', '#1f3a8a'),
    catalogColor('2', 'Cream', '#f5e9c8'),
    catalogColor('3', 'Red', '#cc0000'),
    catalogColor('4', 'Black', '#000000'),
    catalogColor('5', 'Dark gray', '#404040'),
    catalogColor('6', 'Gray', '#808080'),
    catalogColor('7', 'Light gray', '#c0c0c0'),
    catalogColor('8', 'White', '#ffffff'),
    catalogColor('T1', 'Toho green', '#00aa00', brand: 'Toho', series: 'Round'),
  ];

  setUp(() {
    catalog = FakeCatalogRepository(colors);
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    settings = FakeSettingsRepository();
  });

  PatternTemplateCubit build() {
    final FakeIdGenerator ids = FakeIdGenerator();
    return PatternTemplateCubit(
      catalog: catalog,
      settings: settings,
      createPattern: CreateGridPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026, 11, 10))),
        projects: projects,
        patterns: patterns,
        ids: ids,
      ),
      brandSetting: SettingKeys.defaultBeadBrand,
    );
  }

  Future<PatternTemplateCubit> started() async {
    final PatternTemplateCubit cubit = build();
    addTearDown(cubit.close);
    await cubit.start();
    return cubit;
  }

  group('старт', () {
    test('грузит каталог выбранного бренда и берёт цвета, ближайшие к стартовым', () async {
      final PatternTemplateCubit cubit = await started();

      final PatternTemplateState s = cubit.state;
      expect(s.status, TemplateStatus.ready);
      // Бренд по умолчанию — Miyuki: цвета Toho в каталоге узора не участвуют.
      expect(s.catalog.map((c) => c.name), isNot(contains('Toho green')));
      expect(s.colors.map((c) => c.name), <String>['Navy', 'Cream']);
      expect(s.preview, isNotNull);
      expect(s.preview!.grid.width, 12);
      expect(s.preview!.grid.height, 40);
    });

    test('каталог меньше двух цветов — ошибка, «Повторить» перезапускает', () async {
      catalog = FakeCatalogRepository(<CatalogColor>[colors.first]);
      final PatternTemplateCubit cubit = await started();
      expect(cubit.state.status, TemplateStatus.failure);
      expect(cubit.state.problem, TemplateProblem.catalogUnavailable);

      catalog.colors
        ..clear()
        ..addAll(colors);
      await cubit.start();
      expect(cubit.state.status, TemplateStatus.ready);
      expect(cubit.state.problem, isNull);
    });

    test('ошибка хранилища каталога — тоже ошибка загрузки', () async {
      catalog.fail = true;
      final PatternTemplateCubit cubit = await started();
      expect(cubit.state.status, TemplateStatus.failure);
    });

    test('в галерее образцы всех шаблонов 12×12', () async {
      final PatternTemplateCubit cubit = await started();
      expect(cubit.state.gallery.keys, TemplateKind.values);
      expect(cubit.state.gallery.values.every((p) => p.grid.width == 12 && p.grid.height == 12), isTrue);
    });
  });

  group('параметры и предпросмотр', () {
    test('смена шаблона перестраивает предпросмотр', () async {
      final PatternTemplateCubit cubit = await started();
      final before = cubit.state.preview;

      cubit.selectKind(TemplateKind.checker);

      expect(cubit.state.params.kind, TemplateKind.checker);
      expect(cubit.state.preview, isNot(before));
      // Шахматка 2×2 из двух цветов: ячейка (0,0) первого цвета, (2,0) второго.
      expect(cubit.state.preview!.grid.at(0, 0), 1);
      expect(cubit.state.preview!.grid.at(2, 0), 2);
    });

    test('размеры ограничиваются допустимыми', () async {
      final PatternTemplateCubit cubit = await started();

      cubit.setParams(cubit.state.params.copyWith(width: 1000, height: 0));

      expect(cubit.state.params.width, TemplateParams.maxWidth);
      expect(cubit.state.params.height, TemplateParams.minSide);
      expect(cubit.state.preview!.grid.width, TemplateParams.maxWidth);
    });

    test('техника задаёт геометрию схемы: пейот и кирпич сдвигают ячейки', () {
      expect(const TemplateParams().geometry, const GridGeometry.rectangular());
      expect(const TemplateParams(technique: Technique.peyote).geometry, const GridGeometry.peyote());
      expect(const TemplateParams(technique: Technique.brick).geometry, const GridGeometry.brick());
      expect(const TemplateParams(technique: Technique.square).geometry, const GridGeometry.rectangular());
      expect(const TemplateParams(technique: Technique.peyote).isShifted, isTrue);
      expect(const TemplateParams().isShifted, isFalse);
    });

    test('в пейоте зигзаг строится со сдвигом: узор отличается от станка', () async {
      final PatternTemplateCubit cubit = await started();
      cubit.selectKind(TemplateKind.diamonds);
      final loom = cubit.state.preview!.grid;

      cubit.setParams(cubit.state.params.copyWith(technique: Technique.peyote));

      expect(cubit.state.preview!.grid, isNot(loom));
    });

    test('полосы берут все цвета, остальные шаблоны — два первых', () async {
      final PatternTemplateCubit cubit = await started();
      cubit.addColor(cubit.state.catalog.firstWhere((c) => c.name == 'Red'));
      expect(cubit.state.usedColors, 3);
      expect(cubit.state.preview!.palette, hasLength(3));

      cubit.selectKind(TemplateKind.diamonds);
      expect(cubit.state.usedColors, 2);
      expect(cubit.state.preview!.palette, hasLength(2));
    });

    test('градиент подбирает ступени из каталога, L монотонна', () async {
      final PatternTemplateCubit cubit = await started();
      cubit.setColor(0, cubit.state.catalog.firstWhere((c) => c.name == 'Black'));
      cubit.setColor(1, cubit.state.catalog.firstWhere((c) => c.name == 'White'));

      cubit.selectKind(TemplateKind.gradient);

      final List<PatternColor> palette = cubit.state.preview!.palette;
      expect(palette.length, greaterThan(2));
      expect(palette.first.name, 'Black');
      expect(palette.last.name, 'White');
      final List<int> red = palette.map((c) => c.rgb.r).toList();
      expect(red, orderedEquals(<int>[...red]..sort()));
    });

    test('цвета: добавить, заменить, убрать; меньше двух и больше шести не бывает', () async {
      final PatternTemplateCubit cubit = await started();
      final PatternColor red = cubit.state.catalog.firstWhere((c) => c.name == 'Red');

      cubit.removeColor(0);
      expect(cubit.state.colors, hasLength(2), reason: 'меньше двух цветов не оставляем');

      cubit.setColor(1, red);
      expect(cubit.state.colors[1], red);

      for (int i = 0; i < 10; i++) {
        cubit.addColor(red);
      }
      expect(cubit.state.colors, hasLength(PatternTemplateState.maxStripeColors));
      cubit.removeColor(5);
      expect(cubit.state.colors, hasLength(5));

      cubit.selectKind(TemplateKind.border);
      expect(cubit.state.canAddColor, isFalse);
      cubit.addColor(red);
      expect(cubit.state.colors, hasLength(5), reason: 'остальным шаблонам больше двух не нужно');
    });

    test('неверный индекс цвета игнорируется', () async {
      final PatternTemplateCubit cubit = await started();
      final PatternTemplateState before = cubit.state;
      cubit.setColor(9, before.colors.first);
      cubit.removeColor(-1);
      expect(cubit.state, before);
    });

    test('градиент без каталога не получается: предпросмотра нет, есть сообщение', () async {
      final PatternTemplateCubit cubit = await started();
      cubit.emit(cubit.state.copyWith(catalog: const <PatternColor>[]));

      cubit.selectKind(TemplateKind.gradient);

      expect(cubit.state.preview, isNull);
      expect(cubit.state.problem, TemplateProblem.invalidParameters);
    });
  });

  group('сохранение', () {
    test('создаёт сеточный проект с палитрой, техникой и размером бусины', () async {
      final PatternTemplateCubit cubit = await started();
      cubit.selectKind(TemplateKind.zigzag);
      cubit.setParams(
        cubit.state.params.copyWith(technique: Technique.peyote, bead: BeadSize.delica10, width: 8, height: 20),
      );
      cubit.setName('  Мой зигзаг ');

      await cubit.save(fallbackName: 'Запасное');

      final String id = cubit.state.projectId!;
      final Project project = projects.projects[id]!;
      expect(project.name, 'Мой зигзаг');
      expect(project.craft, Craft.beading);
      expect(project.technique, Technique.peyote);
      expect(project.contentKind, ContentKind.grid);
      final GridPattern pattern = patterns.byProject[id]!;
      expect(pattern.geometry, const GridGeometry.peyote());
      expect(pattern.metrics, BeadSize.delica10);
      expect(pattern.grid, cubit.state.preview!.grid);
      expect(pattern.palette.colors.map((c) => c.name), <String>['Navy', 'Cream']);
      // Знаки раздаёт палитра: каждому цвету свой.
      expect(pattern.palette.colors.map((c) => c.symbol).toSet(), hasLength(2));
      expect(pattern.palette.colors.first.components.single.brand, 'Miyuki');
      expect(cubit.state.saving, isFalse);
    });

    test('пустое название — запасное', () async {
      final PatternTemplateCubit cubit = await started();
      await cubit.save(fallbackName: 'Полосы 12×40');
      expect(projects.projects[cubit.state.projectId]!.name, 'Полосы 12×40');
    });

    test('повторное сохранение не создаёт второй проект', () async {
      final PatternTemplateCubit cubit = await started();
      await cubit.save(fallbackName: 'А');
      await cubit.save(fallbackName: 'А');
      expect(projects.projects, hasLength(1));
    });

    test('ошибка хранилища: проект не создан, сообщение, можно повторить', () async {
      final PatternTemplateCubit cubit = await started();
      patterns.failNextSave = const StorageFailure('boom');

      await cubit.save(fallbackName: 'А');

      expect(cubit.state.problem, TemplateProblem.saveFailed);
      expect(cubit.state.projectId, isNull);
      expect(cubit.state.saving, isFalse);
      expect(projects.projects.keys.toSet().difference(projects.deleted), isEmpty);

      await cubit.save(fallbackName: 'А');
      expect(cubit.state.projectId, isNotNull);
    });

    test('без предпросмотра сохранять нечего', () async {
      final PatternTemplateCubit cubit = await started();
      cubit.emit(cubit.state.copyWith(clearPreview: true));
      await cubit.save(fallbackName: 'А');
      expect(cubit.state.problem, TemplateProblem.invalidParameters);
      expect(projects.projects, isEmpty);
    });

    test('цвета узора в палитре без пустых мест: сетка согласована с палитрой', () async {
      final PatternTemplateCubit cubit = await started();
      await cubit.save(fallbackName: 'А');
      final GridPattern pattern = patterns.byProject[cubit.state.projectId]!;
      final PaletteSnapshot palette = pattern.palette;
      expect(
        pattern.grid.cells.every((v) => v >= 0 && v <= palette.length),
        isTrue,
      );
      expect(palette.colors.first.rgb, const Rgb(31, 58, 138));
    });
  });
}
