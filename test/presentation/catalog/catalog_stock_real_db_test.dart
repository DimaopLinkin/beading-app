import 'package:beading/core/id_generator.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/floss_stock_dao.dart';
import 'package:beading/data/floss_stock/drift_floss_stock_repository.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/use_cases/find_similar_colors.dart';
import 'package:beading/presentation/catalog/catalog_cubit.dart';
import 'package:beading/presentation/catalog/catalog_screen.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_clock.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/in_memory_database.dart';

void main() {
  testWidgets('плюс в «Моём запасе» с настоящей базой', (tester) async {
    tester.view
      ..physicalSize = const Size(430, 932)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final CatalogColor dmc310 = catalogColor(
      '310',
      'Black',
      '#000000',
      brand: 'DMC',
      series: 'Mouliné',
      material: CatalogMaterial.floss,
    );
    final FakeCatalogRepository catalog = FakeCatalogRepository(<CatalogColor>[dmc310]);
    final AppDatabase db = createInMemoryDatabase();
    final FakeClock clock = FakeClock(DateTime.utc(2026, 11, 12, 10));
    final DriftFlossStockRepository stock = DriftFlossStockRepository(
      dao: FlossStockDao(db),
      deviceIds: DriftDeviceIdProvider(dao: db.settingsDao, ids: FakeIdGenerator(), clock: clock),
      clock: clock,
      ids: UuidV7IdGenerator(clock: clock),
    );
    final CatalogCubit cubit = CatalogCubit(
      catalog: catalog,
      findSimilar: FindSimilarColors(catalog),
      settings: FakeSettingsRepository(),
      material: CatalogMaterial.floss,
      stock: stock,
    );
    await tester.pumpWidget(
      CupertinoApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: BlocProvider<CatalogCubit>.value(value: cubit, child: const CatalogScreen()),
      ),
    );
    await tester.runAsync(() async {
      await cubit.start();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    await tester.tap(find.text('310'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('stock-more')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('0,5 мот.'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await cubit.close();
      await db.close();
    });
  });
}
