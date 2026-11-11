import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/rgb.dart';

CatalogColor catalogColor(
  String code,
  String name,
  String hex, {
  String brand = 'Miyuki',
  String series = 'Delica',
  CatalogMaterial material = CatalogMaterial.bead,
  String? finish,
}) => CatalogColor(
  material: material,
  brand: brand,
  series: series,
  code: code,
  name: name,
  rgb: Rgb.fromHex(hex),
  finish: finish,
  sizeCode: material == CatalogMaterial.bead ? '11/0' : null,
);

/// Каталог в памяти. Запросы запоминаются; [gate] задерживает ответ следующего поиска.
class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository(this.colors);

  final List<CatalogColor> colors;
  final List<({String query, String? brand})> searches = <({String query, String? brand})>[];
  final List<({Rgb target, String? brand, int count})> nearestCalls = <({Rgb target, String? brand, int count})>[];

  /// Если задан, ближайший `search` дожидается его завершения (после того, как посчитал результат).
  Completer<void>? gate;

  /// Если `true`, все методы возвращают ошибку хранилища.
  bool fail = false;

  @override
  Future<Result<List<CatalogColor>>> search({String query = '', CatalogMaterial? material, String? brand}) async {
    searches.add((query: query, brand: brand));
    if (fail) return const Err<List<CatalogColor>>(StorageFailure('boom'));
    final String q = query.toLowerCase();
    final List<CatalogColor> found = <CatalogColor>[
      for (final CatalogColor c in colors)
        if ((material == null || c.material == material) &&
            (brand == null || c.brand == brand) &&
            (q.isEmpty || c.code.toLowerCase().contains(q) || c.name.toLowerCase().contains(q)))
          c,
    ];
    final Completer<void>? held = gate;
    if (held != null) {
      gate = null;
      await held.future;
    }
    return Success<List<CatalogColor>>(found);
  }

  @override
  Future<Result<List<String>>> brands(CatalogMaterial material) async {
    if (fail) return const Err<List<String>>(StorageFailure('boom'));
    return Success<List<String>>(
      <String>{
        for (final CatalogColor c in colors)
          if (c.material == material) c.brand,
      }.toList()..sort(),
    );
  }

  @override
  Future<Result<CatalogColor?>> find(String brand, String code) async => Success<CatalogColor?>(
    colors.where((c) => c.brand == brand && c.code == code).firstOrNull,
  );

  @override
  Future<Result<List<ColorMatch<CatalogColor>>>> nearest(
    Rgb target, {
    required CatalogMaterial material,
    String? brand,
    int count = 5,
  }) async {
    nearestCalls.add((target: target, brand: brand, count: count));
    if (fail) return const Err<List<ColorMatch<CatalogColor>>>(StorageFailure('boom'));
    final NearestColorMatcher<CatalogColor> matcher = NearestColorMatcher<CatalogColor>(
      colors.where((c) => c.material == material && (brand == null || c.brand == brand)),
      rgbOf: (c) => c.rgb,
    );
    return Success<List<ColorMatch<CatalogColor>>>(matcher.nearest(target, count: count));
  }
}
