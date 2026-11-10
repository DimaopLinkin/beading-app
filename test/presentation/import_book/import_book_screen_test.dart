import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_pattern/use_cases/import_book_pattern.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/presentation/import_book/import_book_cubit.dart';
import 'package:beading/presentation/import_book/import_book_screen.dart';
import 'package:beading/presentation/import_book/import_book_state.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/test_images.dart';

void main() {
  late FakeBookImageSource source;
  late FakePdfRasterizer rasterizer;
  late FakeProjectRepository projects;
  late ImportBookCubit cubit;

  setUp(() {
    source = FakeBookImageSource();
    rasterizer = FakePdfRasterizer();
    projects = FakeProjectRepository();
    final FakeIdGenerator ids = FakeIdGenerator();
    cubit = ImportBookCubit(
      source: source,
      rasterizer: rasterizer,
      importBookPattern: ImportBookPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026))),
        projects: projects,
        patterns: FakeImagePatternRepository(),
        processor: FakeImageProcessor(),
        files: FakeFileStore(),
        ids: ids,
      ),
    );
    addTearDown(cubit.close);
  });

  Widget wrap(CupertinoThemeData theme, {bool camera = true}) => CupertinoApp(
    theme: theme,
    builder: AppTheme.builder,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<ImportBookCubit>.value(
      value: cubit,
      child: ImportBookScreen(cameraAvailable: camera),
    ),
  );

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('выбор источника в теме ${theme.brightness}: три способа', (tester) async {
      await tester.pumpWidget(wrap(theme));

      expect(find.text('Снять на камеру'), findsOneWidget);
      expect(find.text('Выбрать из Фото'), findsOneWidget);
      expect(find.text('Выбрать из Файлов (фото или PDF)'), findsOneWidget);
    });
  }

  testWidgets('на Mac кнопки камеры нет', (tester) async {
    await tester.pumpWidget(wrap(AppTheme.light, camera: false));

    expect(find.text('Снять на камеру'), findsNothing);
  });

  testWidgets('отказ в доступе показывает понятный текст', (tester) async {
    source.next = const Err<List<PickedBookFile>>(StorageFailure('denied'));
    await tester.pumpWidget(wrap(AppTheme.light));

    await tester.tap(find.text('Выбрать из Фото'));
    await tester.pump();

    expect(find.textContaining('Нет доступа к камере или Фото'), findsOneWidget);
  });

  testWidgets('PDF: отмечаем страницы и продолжаем, кнопка выключена пока ничего не выбрано', (tester) async {
    source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
      PickedBookFile(name: 'Схема.pdf', bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46])),
    ]);
    rasterizer.pages = 4;
    await tester.pumpWidget(wrap(AppTheme.light));
    await tester.tap(find.text('Выбрать из Файлов (фото или PDF)'));
    await tester.pumpAndSettle();

    expect(find.text('Выбрано: 0 из 4'), findsOneWidget);
    expect(tester.widget<CupertinoButton>(find.widgetWithText(CupertinoButton, 'Продолжить')).onPressed, isNull);

    await tester.tap(find.text('2'));
    await tester.tap(find.text('4'));
    await tester.pump();
    expect(find.text('Выбрано: 2 из 4'), findsOneWidget);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(rasterizer.rendered.single, <int>[1, 3]);
    expect(find.text('Страница 1'), findsOneWidget);
    expect(find.text('Страница 2'), findsOneWidget);
    expect(find.text('Импортировать'), findsOneWidget);
  });

  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('проверка страниц в теме ${theme.brightness}: поворот, удаление, импорт закрывает экран', (
      tester,
    ) async {
      final Uint8List png = (await tester.runAsync(redBluePng))!;
      source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
        PickedBookFile(name: 'Роза.png', bytes: png),
        PickedBookFile(name: 'Роза2.png', bytes: png),
      ]);
      await tester.pumpWidget(wrap(theme));
      await tester.tap(find.text('Выбрать из Фото'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Страница 1'), findsOneWidget);
      expect(find.text('Страница 2'), findsOneWidget);
      expect(find.widgetWithText(CupertinoTextField, 'Роза'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Повернуть').first);
      await tester.pump();
      expect(cubit.state.pages.first.quarterTurns, 1);

      await tester.tap(find.bySemanticsLabel('Убрать').last);
      await tester.pump();
      expect(cubit.state.pages, hasLength(1));

      await tester.tap(find.text('Импортировать'));
      await tester.pump();
      await tester.pump();

      expect(cubit.state.step, ImportStep.done);
      expect(projects.projects.values.single.name, 'Роза');
    });
  }
}
