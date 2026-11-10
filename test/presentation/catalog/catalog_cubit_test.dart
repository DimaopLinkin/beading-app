import 'dart:async';

import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/use_cases/find_similar_colors.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/presentation/catalog/catalog_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';
import '../../support/fake_settings_repository.dart';

void main() {
  final CatalogColor red = catalogColor('DB0010', 'Red', '#cc0000');
  final CatalogColor darkRed = catalogColor('DB0011', 'Dark Red', '#bb0000');
  final CatalogColor tohoRed = catalogColor('5', 'Opaque Red', '#cd0101', brand: 'Toho', series: 'Round');
  final CatalogColor tohoBlue = catalogColor('8', 'Blue', '#0000cc', brand: 'Toho', series: 'Round');

  late FakeCatalogRepository catalog;
  late FakeSettingsRepository settings;

  setUp(() {
    catalog = FakeCatalogRepository(<CatalogColor>[red, darkRed, tohoRed, tohoBlue]);
    settings = FakeSettingsRepository();
  });

  CatalogCubit make({bool useBrandSetting = true}) {
    final CatalogCubit cubit = CatalogCubit(
      catalog: catalog,
      findSimilar: FindSimilarColors(catalog),
      settings: settings,
      brandSetting: useBrandSetting ? SettingKeys.defaultBeadBrand : null,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('start: бренды, вкладка из настройки «производитель по умолчанию» и её цвета', () async {
    settings.values[SettingKeys.defaultBeadBrand.name] = 'Toho';
    final CatalogCubit cubit = make();

    await cubit.start();

    expect(cubit.state.status, CatalogStatus.ready);
    expect(cubit.state.tabs.map((t) => t.label), <String>['Miyuki', 'Toho']);
    expect(cubit.state.tab?.brand, 'Toho');
    expect(cubit.state.colors, <CatalogColor>[tohoRed, tohoBlue]);
  });

  test('start: бренда из настройки нет в каталоге — открывается «Все»', () async {
    settings.values[SettingKeys.defaultBeadBrand.name] = 'Preciosa';
    final CatalogCubit cubit = make();

    await cubit.start();

    expect(cubit.state.tab, isNull);
    expect(cubit.state.colors, hasLength(4));
  });

  test('start без настройки бренда: «Все»', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);

    await cubit.start();

    expect(cubit.state.tab, isNull);
    expect(cubit.state.colors, hasLength(4));
  });

  test('start: ошибка каталога — failure, retry после починки показывает цвета', () async {
    catalog.fail = true;
    final CatalogCubit cubit = make();
    await cubit.start();
    expect(cubit.state.status, CatalogStatus.failure);

    catalog.fail = false;
    await cubit.retry();

    expect(cubit.state.status, CatalogStatus.ready);
    expect(cubit.state.colors, isNotEmpty);
  });

  test('выбор вкладки фильтрует по бренду, «все» снимает фильтр', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();

    await cubit.selectTab(cubit.state.tabs.first);
    expect(cubit.state.colors, <CatalogColor>[red, darkRed]);
    expect(catalog.searches.last.brand, 'Miyuki');

    await cubit.selectTab(null);
    expect(cubit.state.colors, hasLength(4));
  });

  test('поиск идёт внутри выбранной вкладки; пробелы по краям отбрасываются', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();
    await cubit.selectTab(cubit.state.tabs.last);

    await cubit.setQuery('  red ');

    expect(cubit.state.query, '  red ');
    expect(catalog.searches.last, (query: 'red', brand: 'Toho'));
    expect(cubit.state.colors, <CatalogColor>[tohoRed]);
  });

  test('поиск без совпадений — пустой список в состоянии ready', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();

    await cubit.setQuery('zzz');

    expect(cubit.state.status, CatalogStatus.ready);
    expect(cubit.state.colors, isEmpty);
  });

  test('ответ устаревшего поиска не затирает результат нового', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();

    final Completer<void> gate = catalog.gate = Completer<void>();
    final Future<void> slow = cubit.setQuery('red');
    await cubit.setQuery('blue');
    gate.complete();
    await slow;

    expect(cubit.state.colors, <CatalogColor>[tohoBlue]);
  });

  test('select: пять ближайших среди всех брендов без самого цвета, с мерой похожести', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();

    await cubit.select(red);

    final SimilarSelection selection = cubit.state.selection!;
    expect(selection.source, red);
    expect(selection.matches!.map((m) => m.color.code), <String>['5', 'DB0011', '8']);
    expect(selection.matches!.first.similarity.percent, greaterThan(95));
  });

  test('select: пока идёт поиск, matches == null, потом заполняется', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();

    final Future<void> selecting = cubit.select(red);
    expect(cubit.state.selection, SimilarSelection(source: red));
    await selecting;

    expect(cubit.state.selection!.matches, isNotNull);
  });

  test('select: ошибка подбора запоминается, цвет остаётся выбранным', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();
    catalog.fail = true;

    await cubit.select(red);

    expect(cubit.state.selection!.source, red);
    expect(cubit.state.selection!.failure, isNotNull);
    expect(cubit.state.selection!.matches, isNull);
  });

  test('clearSelection закрывает выбор; ответ подбора, пришедший позже, его не возвращает', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();

    final Future<void> selecting = cubit.select(red);
    cubit.clearSelection();
    await selecting;

    expect(cubit.state.selection, isNull);
  });

  test('вкладки по сериям: у бренда с несколькими сериями в названии есть серия, фильтр по серии', () async {
    final CatalogColor rocaille = catalogColor('R1', 'Rocaille Red', '#cc0001', series: 'Rocailles');
    catalog = FakeCatalogRepository(<CatalogColor>[red, rocaille, tohoRed]);
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();

    expect(cubit.state.tabs.map((t) => t.label), <String>['Miyuki Delica', 'Miyuki Rocailles', 'Toho']);

    await cubit.selectTab(cubit.state.tabs[1]);
    expect(cubit.state.colors, <CatalogColor>[rocaille]);
  });

  test('настройка бренда не перебивает вкладку, выбранную до ответа настройки и при «Повторить»', () async {
    settings.values[SettingKeys.defaultBeadBrand.name] = 'Toho';
    final CatalogCubit cubit = make();
    await cubit.start();
    await cubit.selectTab(cubit.state.tabs.first);

    await cubit.retry();

    expect(cubit.state.tab?.brand, 'Miyuki');
  });

  test('clearSelection на закрытом кубите не падает', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.close();

    cubit.clearSelection();
  });

  test('выбор другого цвета из списка похожих заменяет выбор', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();
    await cubit.select(red);

    await cubit.select(tohoRed);

    expect(cubit.state.selection!.source, tohoRed);
    expect(cubit.state.selection!.matches!.map((m) => m.color.code), isNot(contains('5')));
  });

  test('закрытый кубит не падает от позднего ответа', () async {
    final CatalogCubit cubit = make(useBrandSetting: false);
    await cubit.start();
    final Completer<void> gate = catalog.gate = Completer<void>();

    final Future<void> pending = cubit.setQuery('red');
    await cubit.close();
    gate.complete();
    await pending;
  });
}
