import 'package:beading/core/failure.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/color_similarity.dart';
import 'package:beading/domain/catalog/use_cases/find_similar_colors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_catalog_repository.dart';

void main() {
  final CatalogColor red = catalogColor('DB0010', 'Red', '#cc0000');
  final CatalogColor darkRed = catalogColor('DB0011', 'Dark Red', '#bb0000');
  final CatalogColor tohoRed = catalogColor('5', 'Toho Red', '#cd0101', brand: 'Toho', series: 'Round');
  final CatalogColor blue = catalogColor('DB0020', 'Blue', '#0000cc');
  final CatalogColor floss = catalogColor(
    '310',
    'Black',
    '#cc0000',
    brand: 'DMC',
    series: 'Mouliné',
    material: CatalogMaterial.floss,
  );

  late FakeCatalogRepository catalog;

  setUp(() => catalog = FakeCatalogRepository(<CatalogColor>[red, darkRed, tohoRed, blue, floss]));

  test('возвращает ближайшие без самого выбранного цвета, самые близкие первыми', () async {
    final List<SimilarColor> result = (await FindSimilarColors(catalog)(red)).valueOrNull!;

    expect(result.map((s) => s.color.code), <String>['5', 'DB0011', 'DB0020']);
    expect(
      result.map((s) => s.similarity.deltaE),
      orderedEquals(result.map((s) => s.similarity.deltaE).toList()..sort()),
    );
    expect(result.first.similarity.level, SimilarityLevel.nearlyIdentical);
  });

  test('ищет по материалу выбранного цвета и среди всех брендов', () async {
    await FindSimilarColors(catalog)(red);

    expect(catalog.nearestCalls.single.brand, isNull);
    expect(catalog.nearestCalls.single.target, red.rgb);
  });

  test('запрашивает на один больше, чтобы после отбрасывания себя осталось ровно count', () async {
    final List<SimilarColor> result = (await FindSimilarColors(catalog)(red, count: 2)).valueOrNull!;

    expect(catalog.nearestCalls.single.count, 3);
    expect(result, hasLength(2));
  });

  test('бренд ограничивает поиск', () async {
    await FindSimilarColors(catalog)(red, brand: 'Toho');

    expect(catalog.nearestCalls.single.brand, 'Toho');
  });

  test('нитки не попадают в подбор бисера', () async {
    final List<SimilarColor> result = (await FindSimilarColors(catalog)(red)).valueOrNull!;

    expect(result.map((s) => s.color.material).toSet(), <CatalogMaterial>{CatalogMaterial.bead});
  });

  test('единственный цвет в каталоге: похожих нет', () async {
    catalog = FakeCatalogRepository(<CatalogColor>[red]);

    expect((await FindSimilarColors(catalog)(red)).valueOrNull, isEmpty);
  });

  test('ошибка каталога возвращается как есть', () async {
    catalog.fail = true;

    expect((await FindSimilarColors(catalog)(red)).failureOrNull, isA<StorageFailure>());
  });
}
