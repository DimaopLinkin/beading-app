import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/picked_book_file.dart';
import 'package:beading/domain/image_pattern/use_cases/import_book_pattern.dart';
import 'package:beading/domain/projects/craft.dart';
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
  late ImportBookPattern importUseCase;

  setUp(() {
    source = FakeBookImageSource();
    rasterizer = FakePdfRasterizer();
    projects = FakeProjectRepository();
    final FakeIdGenerator ids = FakeIdGenerator();
    importUseCase = ImportBookPattern(
      createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026))),
      projects: projects,
      patterns: FakeImagePatternRepository(),
      processor: FakeImageProcessor(),
      files: FakeFileStore(),
      ids: ids,
    );
    cubit = ImportBookCubit(source: source, rasterizer: rasterizer, importBookPattern: importUseCase);
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

  testWidgets('пока файл открывается, виден индикатор и текст, потом пропадает', (tester) async {
    final Completer<Result<List<PickedBookFile>>> gate = Completer<Result<List<PickedBookFile>>>();
    final ImportBookCubit slow = ImportBookCubit(
      source: _GatedSource(gate),
      rasterizer: rasterizer,
      importBookPattern: importUseCase,
    );
    addTearDown(slow.close);
    await tester.pumpWidget(
      CupertinoApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<ImportBookCubit>.value(value: slow, child: const ImportBookScreen(cameraAvailable: false)),
      ),
    );

    await tester.tap(find.text('Выбрать из Фото'));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('import-busy')), findsOneWidget);
    expect(find.text('Открываем файл…'), findsOneWidget);

    gate.complete(const Success<List<PickedBookFile>>(<PickedBookFile>[]));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('import-busy')), findsNothing);
  });

  testWidgets('пустой PDF: понятный текст со значком и кнопка «Выбрать другой файл»', (tester) async {
    source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
      PickedBookFile(name: 'Пусто.pdf', bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46])),
    ]);
    rasterizer.pages = 0;
    await tester.pumpWidget(wrap(AppTheme.light));

    await tester.tap(find.text('Выбрать из Файлов (фото или PDF)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('нет страниц'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('pick-another')), findsNothing);
  });

  testWidgets('ошибка при отрисовке страниц PDF: кнопка «Выбрать другой файл» ведёт к выбору источника', (
    tester,
  ) async {
    source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
      PickedBookFile(name: 'Схема.pdf', bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46])),
    ]);
    await tester.pumpWidget(wrap(AppTheme.light));
    await tester.tap(find.text('Выбрать из Файлов (фото или PDF)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pump();
    rasterizer.failure = const StorageFailure('boom');
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось открыть PDF.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('pick-another')));
    await tester.pumpAndSettle();
    expect(find.text('Выбрать из Фото'), findsOneWidget);
  });

  testWidgets('выбранная страница PDF и выбранная техника отмечены галочкой, а не только цветом', (tester) async {
    source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
      PickedBookFile(name: 'Схема.pdf', bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46])),
    ]);
    rasterizer.pages = 30;
    await tester.pumpWidget(wrap(AppTheme.light));
    await tester.tap(find.text('Выбрать из Файлов (фото или PDF)'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.check_mark), findsNothing);

    await tester.tap(find.text('2'));
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);

    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
    await tester.tap(find.text('Вышивка'));
    await tester.pump();
    expect(cubit.state.craft, Craft.crossStitch);
    expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
  });

  testWidgets('нумерация шагов считается по источнику: для фото «из 2», для PDF «из 3»', (tester) async {
    await tester.pumpWidget(wrap(AppTheme.light));
    expect(find.text('Шаг 1 из 2'), findsOneWidget);

    source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
      PickedBookFile(name: 'Схема.pdf', bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46])),
    ]);
    await tester.tap(find.text('Выбрать из Файлов (фото или PDF)'));
    await tester.pumpAndSettle();
    expect(find.text('Шаг 2 из 3'), findsOneWidget);
  });

  testWidgets('последняя миниатюра страницы PDF прокручивается выше нижней панели', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    source.next = Success<List<PickedBookFile>>(<PickedBookFile>[
      PickedBookFile(name: 'Схема.pdf', bytes: Uint8List.fromList(<int>[0x25, 0x50, 0x44, 0x46])),
    ]);
    rasterizer.pages = 60;
    await tester.pumpWidget(wrap(AppTheme.light));
    await tester.tap(find.text('Выбрать из Файлов (фото или PDF)'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -10000));
    await tester.pumpAndSettle();

    final Rect last = tester.getRect(find.text('60'));
    final Rect bar = tester.getRect(find.widgetWithText(CupertinoButton, 'Продолжить'));
    expect(last.bottom, lessThanOrEqualTo(bar.top));
  });
}

class _GatedSource implements BookImageSource {
  _GatedSource(this.gate);

  final Completer<Result<List<PickedBookFile>>> gate;

  @override
  Future<Result<List<PickedBookFile>>> takePhoto() => gate.future;

  @override
  Future<Result<List<PickedBookFile>>> pickPhotos() => gate.future;

  @override
  Future<Result<List<PickedBookFile>>> pickFiles() => gate.future;
}
