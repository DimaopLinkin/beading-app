import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/sharing/zip_biser_codec.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';
import 'package:beading/domain/sharing/biser/export_projects.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';
import 'package:beading/presentation/sharing/data_transfer_host.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/biser_samples.dart';
import '../../support/fake_biser.dart';
import '../../support/fake_book_work.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_image_pattern.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_work_sessions.dart';

class _Incoming implements IncomingBiserFiles {
  // ignore: close_sinks, закрывается в tearDown теста.
  final StreamController<Result<BiserFile>> controller = StreamController<Result<BiserFile>>();

  @override
  Stream<Result<BiserFile>> get files => controller.stream;
}

void main() {
  late FakeProjectRepository projects;
  late _Incoming incoming;
  late DataTransferCubit cubit;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Uint8List fileWith(int projectCount) =>
      const ZipBiserCodec().encode(randomBundle(6, projects: projectCount)).valueOrNull!;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    CupertinoApp(
      navigatorKey: navigatorKey,
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          DataTransferHost(cubit: cubit, incoming: incoming, navigatorKey: navigatorKey, child: child!),
      home: const CupertinoPageScaffold(child: Text('главный')),
    ),
  );

  setUp(() {
    projects = FakeProjectRepository();
    incoming = _Incoming();
    final FakeGridPatternRepository grids = FakeGridPatternRepository();
    final FakeGridProgressStore progress = FakeGridProgressStore();
    final FakeCellProgressStore cellProgress = FakeCellProgressStore();
    final FakeImagePatternRepository images = FakeImagePatternRepository();
    final FakeBookWorkRepository bookWork = FakeBookWorkRepository();
    final FakeWorkSessionRepository workSessions = FakeWorkSessionRepository();
    final FakeFileStore files = FakeFileStore();
    cubit = DataTransferCubit(
      export: ExportProjects(
        projects: projects,
        grids: grids,
        progress: progress,
        cellProgress: cellProgress,
        images: images,
        bookWork: bookWork,
        workSessions: workSessions,
        files: files,
        codec: const ZipBiserCodec(),
        clock: FakeClock(DateTime.utc(2026, 11, 10)),
        appInfo: _AppInfo(),
      ),
      import: ImportBiser(
        codec: const ZipBiserCodec(),
        projects: projects,
        grids: grids,
        progress: progress,
        cellProgress: cellProgress,
        images: images,
        bookWork: bookWork,
        workSessions: workSessions,
        files: files,
        ids: FakeIdGenerator(),
        unitOfWork: PassThroughUnitOfWork(),
      ),
      sharer: FakeFileSharer(),
      picker: FakeBiserFilePicker(),
    );
    addTearDown(cubit.close);
    addTearDown(incoming.controller.close);
  });

  testWidgets('открытый системой файл: лист подтверждения → «Добавить» → сообщение «Готово»', (tester) async {
    await pump(tester);

    incoming.controller.add(Success<BiserFile>(BiserFile(name: 'a.biser', bytes: fileWith(2))));
    await tester.pumpAndSettle();
    expect(find.text('В файле проектов: 2'), findsOneWidget);
    expect(find.text('Добавить в библиотеку'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('import-as-new')));
    await tester.pumpAndSettle();
    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('Добавлено проектов: 2. Пропущено: 0.'), findsOneWidget);

    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('Готово'), findsNothing);
    expect(projects.projects, hasLength(2));
  });

  testWidgets('совпавшие проекты: два варианта; «Отмена» ничего не добавляет', (tester) async {
    for (final BiserProject item in randomBundle(6, projects: 2).projects) {
      await projects.save(item.project);
    }
    await pump(tester);

    incoming.controller.add(Success<BiserFile>(BiserFile(name: 'a.biser', bytes: fileWith(2))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Уже есть в библиотеке: 2'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('import-skip')), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(cubit.state.pending, isNull);
    expect(projects.projects, hasLength(2));
  });

  testWidgets('«Пропустить уже существующие»', (tester) async {
    for (final BiserProject item in randomBundle(6, projects: 2).projects) {
      await projects.save(item.project);
    }
    await pump(tester);
    incoming.controller.add(Success<BiserFile>(BiserFile(name: 'a.biser', bytes: fileWith(2))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('import-skip')));
    await tester.pumpAndSettle();
    expect(find.text('Добавлено проектов: 0. Пропущено: 2.'), findsOneWidget);
  });

  testWidgets('повреждённый файл показывает понятную ошибку', (tester) async {
    await pump(tester);
    incoming.controller.add(Success<BiserFile>(BiserFile(name: 'a.biser', bytes: Uint8List.fromList(<int>[1, 2]))));
    await tester.pumpAndSettle();
    expect(find.text('Не получилось'), findsOneWidget);
    expect(find.textContaining('Канители'), findsOneWidget);
  });

  testWidgets('системная ошибка чтения файла — общий текст', (tester) async {
    await pump(tester);
    incoming.controller.add(const Err<BiserFile>(StorageFailure('нет доступа')));
    await tester.pumpAndSettle();
    expect(find.text('Не получилось. Попробуйте ещё раз.'), findsOneWidget);
  });
}

class _AppInfo implements AppInfoProvider {
  @override
  Future<AppInfo> load() async => const AppInfo(version: '0.1.0', build: '1');
}
