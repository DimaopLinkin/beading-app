import 'package:beading/core/failure.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/delete_project.dart';
import 'package:beading/domain/projects/use_cases/duplicate_project.dart';
import 'package:beading/domain/projects/use_cases/rename_project.dart';
import 'package:beading/domain/projects/use_cases/watch_projects.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/library_cubit.dart';
import 'package:beading/presentation/library/library_screen.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:beading/presentation/library/project_card.dart';
import 'package:beading/presentation/library/project_thumbnail_provider.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';
import 'library_cubit_test.dart' show project;

class _MarkerThumbnails implements ProjectThumbnailProvider {
  @override
  bool supports(Project project) => project.name == 'С превью';

  @override
  Widget build(BuildContext context, Project project) => const Text('превью-маркер');
}

void main() {
  late FakeProjectRepository repository;
  late NewProjectRegistry newProjects;
  late ProjectThumbnailRegistry thumbnails;
  late List<String> opened;

  setUp(() {
    repository = FakeProjectRepository();
    newProjects = NewProjectRegistry();
    thumbnails = ProjectThumbnailRegistry();
    opened = <String>[];
  });

  Future<LibraryCubit> pumpScreen(
    WidgetTester tester, {
    CupertinoThemeData theme = AppTheme.light,
    VoidCallback? onOpenSettings,
    VoidCallback? onOpenCatalog,
    void Function(BuildContext, Project)? onOpenMaterials,
  }) async {
    final FakeProjectRepository source = repository;
    final LibraryCubit cubit = LibraryCubit(
      watchProjects: WatchProjects(source),
      deleteProject: DeleteProject(source),
      renameProject: RenameProject(source),
      duplicateProject: DuplicateProject(
        repository: source,
        ids: FakeIdGenerator(),
        clock: FakeClock(DateTime.utc(2026, 2)),
      ),
    )..start();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      CupertinoApp(
        theme: theme,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<LibraryCubit>.value(
          value: cubit,
          child: LibraryScreen(
            newProjects: newProjects,
            thumbnails: thumbnails,
            onOpenProject: (_, p) => opened.add(p.id),
            onOpenSettings: onOpenSettings,
            onOpenCatalog: onOpenCatalog,
            onOpenMaterials: onOpenMaterials,
          ),
        ),
      ),
    );
    await tester.pump();
    return cubit;
  }

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    group('тема ${theme.brightness}', () {
      testWidgets('пустая библиотека показывает подсказку', (tester) async {
        await pumpScreen(tester, theme: theme);

        expect(find.text('Мои работы'), findsWidgets);
        expect(find.text('Пока нет работ'), findsOneWidget);
      });

      testWidgets('список показывает карточки с ремеслом и техникой', (tester) async {
        repository.projects['a'] = project('a', 'Браслет Ёлка');
        repository.projects['b'] = project('b', 'Салфетка', craft: Craft.crossStitch);
        await pumpScreen(tester, theme: theme);

        expect(find.text('Браслет Ёлка'), findsOneWidget);
        expect(find.text('Бисер · Станок'), findsOneWidget);
        expect(find.text('Вышивка · Крестик'), findsOneWidget);
      });
    });
  }

  testWidgets('поиск без совпадений показывает пустой результат, сброс возвращает список', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    await pumpScreen(tester);

    await tester.enterText(find.byType(CupertinoSearchTextField), 'zzz');
    await tester.pump();
    expect(find.text('Ничего не найдено'), findsOneWidget);

    await tester.tap(find.text('Сбросить фильтры'));
    await tester.pump();
    expect(find.text('Браслет'), findsOneWidget);
    expect(tester.widget<CupertinoSearchTextField>(find.byType(CupertinoSearchTextField)).controller!.text, isEmpty);
  });

  testWidgets('чип ремесла оставляет только его проекты', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    repository.projects['b'] = project('b', 'Салфетка', craft: Craft.crossStitch);
    await pumpScreen(tester);

    await tester.tap(find.text('Вышивка').first);
    await tester.pump();

    expect(find.text('Браслет'), findsNothing);
    expect(find.text('Салфетка'), findsOneWidget);
  });

  testWidgets('чип статуса фильтрует по статусу', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    repository.projects['b'] = project('b', 'Готовое', status: ProjectStatus.done);
    await pumpScreen(tester);

    await tester.tap(find.text('Готово').first);
    await tester.pump();

    expect(find.text('Браслет'), findsNothing);
    expect(find.text('Готовое'), findsOneWidget);
  });

  testWidgets('превью берётся у зарегистрированного провайдера', (tester) async {
    thumbnails.register(_MarkerThumbnails());
    repository.projects['a'] = project('a', 'С превью');
    repository.projects['b'] = project('b', 'Без превью');
    await pumpScreen(tester);

    expect(find.text('превью-маркер'), findsOneWidget);
  });

  testWidgets('кнопка настроек вызывает onOpenSettings', (tester) async {
    var settingsOpened = 0;
    await pumpScreen(tester, onOpenSettings: () => settingsOpened++);

    await tester.tap(find.bySemanticsLabel('Настройки'));

    expect(settingsOpened, 1);
  });

  testWidgets('без onOpenSettings кнопки настроек нет', (tester) async {
    await pumpScreen(tester);

    expect(find.bySemanticsLabel('Настройки'), findsNothing);
  });

  testWidgets('кнопка каталога вызывает onOpenCatalog; без него кнопки нет', (tester) async {
    var catalogOpened = 0;
    await pumpScreen(tester, onOpenCatalog: () => catalogOpened++);

    await tester.tap(find.bySemanticsLabel('Каталог цветов'));

    expect(catalogOpened, 1);
  });

  testWidgets('без onOpenCatalog кнопки каталога нет', (tester) async {
    await pumpScreen(tester);

    expect(find.bySemanticsLabel('Каталог цветов'), findsNothing);
  });

  Project gridProject(String id, {Craft craft = Craft.beading}) => Project(
    id: id,
    name: 'Схема $id',
    status: ProjectStatus.idea,
    craft: craft,
    technique: Technique.defaultFor(craft),
    contentKind: ContentKind.grid,
    notes: '',
    coverPath: null,
    lastWorkedAt: DateTime.utc(2026),
  );

  testWidgets('в меню бисерной схемы есть «Материалы» и открывают материалы этого проекта', (tester) async {
    repository.projects['g'] = gridProject('g');
    final List<String> materials = <String>[];
    await pumpScreen(tester, onOpenMaterials: (_, p) => materials.add(p.id));

    await tester.longPress(find.text('Схема g'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, 'Материалы'));
    await tester.pumpAndSettle();

    expect(materials, <String>['g']);
  });

  testWidgets('«Материалы» не предлагаются для схем из книги, вышивки и без обработчика', (tester) async {
    repository.projects['book'] = project('book', 'Страница книги');
    repository.projects['cross'] = gridProject('cross', craft: Craft.crossStitch);
    await pumpScreen(tester, onOpenMaterials: (_, _) {});

    for (final String name in <String>['Страница книги', 'Схема cross']) {
      await tester.longPress(find.text(name));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CupertinoActionSheetAction, 'Материалы'), findsNothing);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('без onOpenMaterials пункта «Материалы» нет даже у бисерной схемы', (tester) async {
    repository.projects['g'] = gridProject('g');
    await pumpScreen(tester);

    await tester.longPress(find.text('Схема g'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(CupertinoActionSheetAction, 'Материалы'), findsNothing);
  });

  testWidgets('нажатие на карточку открывает проект', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    await pumpScreen(tester);

    await tester.tap(find.text('Браслет'));

    expect(opened, <String>['a']);
  });

  group('удаление', () {
    Future<void> openDeleteConfirmation(WidgetTester tester) async {
      await tester.drag(find.text('Браслет'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
    }

    testWidgets('свайп и «Удалить» спрашивают подтверждение; отмена оставляет проект', (tester) async {
      repository.projects['a'] = project('a', 'Браслет');
      await pumpScreen(tester);

      await openDeleteConfirmation(tester);
      expect(find.text('Удалить «Браслет»?'), findsOneWidget);
      expect(repository.deleted, isEmpty);

      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(repository.deleted, isEmpty);
      expect(find.text('Браслет'), findsOneWidget);
    });

    testWidgets('подтверждение удаляет проект из списка', (tester) async {
      repository.projects['a'] = project('a', 'Браслет');
      await pumpScreen(tester);

      await openDeleteConfirmation(tester);
      await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Удалить'));
      await tester.pumpAndSettle();

      expect(repository.deleted, contains('a'));
      expect(find.text('Браслет'), findsNothing);
      expect(find.text('Пока нет работ'), findsOneWidget);
    });
  });

  testWidgets('удаление из меню долгого нажатия тоже просит подтверждение', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    await pumpScreen(tester);

    await tester.longPress(find.text('Браслет'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, 'Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить «Браслет»?'), findsOneWidget);
    expect(repository.deleted, isEmpty);
  });

  testWidgets('ошибка удаления показывает сообщение', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    await pumpScreen(tester);
    repository.deleted.add('a'); // проект исчез из хранилища, а список ещё не обновился

    await tester.drag(find.text('Браслет'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, 'Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Этой работы уже нет.'), findsOneWidget);
  });

  testWidgets('ошибка дублирования показывает сообщение', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    await pumpScreen(tester);
    repository.deleted.add('a');

    await tester.drag(find.text('Браслет'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дублировать'));
    await tester.pumpAndSettle();

    expect(find.text('Этой работы уже нет.'), findsOneWidget);
  });

  testWidgets('нажатие на открытую строку закрывает её и не открывает проект', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    await pumpScreen(tester);
    final double closedX = tester.getTopLeft(find.text('Браслет')).dx;

    await tester.drag(find.text('Браслет'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Браслет')).dx, lessThan(closedX));

    await tester.tap(find.byType(ProjectCard));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Браслет')).dx, closedX);
    expect(opened, isEmpty);
  });

  testWidgets('свайп «Дублировать» добавляет копию', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    await pumpScreen(tester);

    await tester.drag(find.text('Браслет'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Дублировать'));
    await tester.pumpAndSettle();

    expect(find.text('Браслет (копия)'), findsOneWidget);
  });

  testWidgets('долгое нажатие открывает меню, «Переименовать» меняет название', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    await pumpScreen(tester);

    await tester.longPress(find.text('Браслет'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, 'Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(CupertinoAlertDialog), matching: find.byType(CupertinoTextField)),
      'Колье',
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Колье'), findsOneWidget);
    expect(repository.projects['a']!.name, 'Колье');
  });

  testWidgets('пустое название при переименовании показывает сообщение об ошибке', (tester) async {
    repository.projects['a'] = project('a', 'Браслет');
    await pumpScreen(tester);

    await tester.longPress(find.text('Браслет'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, 'Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(of: find.byType(CupertinoAlertDialog), matching: find.byType(CupertinoTextField)),
      '  ',
    );
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Не получилось'), findsOneWidget);
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('Не получилось'), findsNothing);
    expect(find.text('Браслет'), findsOneWidget);
  });

  group('лист «Новый проект»', () {
    NewProjectEntry entry(String id, Craft craft, List<String> log) => NewProjectEntry(
      id: id,
      craft: craft,
      title: (_) => 'Пункт $id',
      icon: CupertinoIcons.add,
      onSelected: (_) async => log.add(id),
    );

    testWidgets('без пунктов объясняет, что способы появятся позже', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel('Добавить проект'));
      await tester.pumpAndSettle();

      expect(find.text('Новый проект'), findsOneWidget);
      expect(find.text('Способы создания появятся в следующих версиях.'), findsOneWidget);
    });

    testWidgets('показывает пункты выбранного ремесла и запускает выбранный', (tester) async {
      final List<String> log = <String>[];
      newProjects
        ..register(entry('book', Craft.beading, log))
        ..register(entry('stitch', Craft.crossStitch, log));
      await pumpScreen(tester);

      await tester.tap(find.bySemanticsLabel('Добавить проект'));
      await tester.pumpAndSettle();
      expect(find.text('Пункт book'), findsOneWidget);
      expect(find.text('Пункт stitch'), findsNothing);

      await tester.tap(
        find.descendant(of: find.byType(CupertinoSlidingSegmentedControl<Craft>), matching: find.text('Вышивка')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Пункт stitch'), findsOneWidget);

      await tester.tap(find.text('Пункт stitch'));
      await tester.pumpAndSettle();
      expect(log, <String>['stitch']);
      expect(find.text('Новый проект'), findsNothing);
    });

    testWidgets('при выбранном чипе ремесла лист открывается на нём', (tester) async {
      newProjects
        ..register(entry('book', Craft.beading, <String>[]))
        ..register(entry('stitch', Craft.crossStitch, <String>[]));
      await pumpScreen(tester);
      await tester.tap(find.text('Вышивка').first);
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Добавить проект'));
      await tester.pumpAndSettle();

      expect(find.text('Пункт stitch'), findsOneWidget);
    });
  });

  testWidgets('ошибка загрузки показывает «Повторить»', (tester) async {
    final _BrokenOnce broken = _BrokenOnce();
    repository = broken;
    await pumpScreen(tester);
    await tester.pump();

    expect(find.text('Не удалось загрузить работы'), findsOneWidget);

    await tester.tap(find.text('Повторить'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Пока нет работ'), findsOneWidget);
  });
}

class _BrokenOnce extends FakeProjectRepository {
  bool _failed = false;

  @override
  Stream<List<Project>> watchAll() {
    if (!_failed) {
      _failed = true;
      return Stream<List<Project>>.error(const StorageFailure('диск'));
    }
    return super.watchAll();
  }
}
