import 'dart:convert';
import 'dart:io';

import 'package:beading/core/result.dart';
import 'package:beading/data/catalog/catalog_asset_source.dart';
import 'package:beading/data/catalog/catalog_file_parser.dart';
import 'package:beading/domain/catalog/catalog_file.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/settings/bead_brands.dart';
import 'package:beading/domain/settings/floss_brands.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:flutter_test/flutter_test.dart';

/// Проверяет настоящие файлы `assets/catalog`: ошибка в данных ловится здесь, а не на устройстве.
void main() {
  final List<File> files =
      Directory('assets/catalog').listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('каталог бисера не пуст', () {
    expect(files, isNotEmpty);
  });

  const Map<String, int> minimum = <String, int>{'miyuki_delica_11': 1300, 'toho_round_11': 900, 'dmc_floss': 480};

  for (final File file in files) {
    final String id = catalogFileId(file.path);
    test('$id: валиден (уникальные артикулы, корректный RGB)', () {
      final Result<CatalogFile> parsed = parseCatalogFile(id, file.readAsStringSync());
      expect(parsed.failureOrNull?.message, isNull);
      final CatalogFile catalog = parsed.valueOrNull!;
      expect(catalog.colors.length, greaterThanOrEqualTo(minimum[id] ?? 1));
      expect(catalog.colors.map((c) => c.name).every((n) => n.isNotEmpty), isTrue);
    });
  }

  const Set<String> finishes = <String>{
    'opaque',
    'transparent',
    'luster',
    'matte',
    'frosted',
    'ceylon',
    'rainbow',
    'lined',
    'gold_lined',
    'silver_lined',
    'semi_glazed',
    'inside_dyed',
    'galvanized',
    'metallic',
  };

  test('глобально уникальные id, известные отделки', () {
    final Set<String> ids = <String>{};
    for (final File file in files) {
      final CatalogFile catalog = parseCatalogFile(catalogFileId(file.path), file.readAsStringSync()).valueOrNull!;
      for (final c in catalog.colors) {
        expect(ids.add(c.id), isTrue, reason: 'повтор ${c.id} в ${file.path}');
        if (c.material == CatalogMaterial.bead) {
          expect(finishes, contains(c.finish), reason: '${c.id}: неизвестная отделка ${c.finish}');
        }
      }
    }
  });

  Set<String> brandsOf(CatalogMaterial material) => <String>{
    for (final File f in files)
      if (parseCatalogFile(catalogFileId(f.path), f.readAsStringSync()).valueOrNull! case final CatalogFile c
          when c.material == material)
        c.brand,
  };

  test('список брендов в настройках совпадает с брендами бисера в каталоге', () {
    expect(beadBrandChoices.toSet(), brandsOf(CatalogMaterial.bead));
  });

  test('список брендов мулине в настройках совпадает с каталогом, бренд по умолчанию есть в нём', () {
    expect(flossBrandChoices.toSet(), brandsOf(CatalogMaterial.floss));
    expect(brandsOf(CatalogMaterial.floss), contains(SettingKeys.defaultFlossBrand.defaultValue));
  });

  test('у каждого файла мулине записано происхождение данных (`source`)', () {
    for (final File f in files) {
      final Map<String, Object?> json = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      if (json['material'] == 'floss') {
        expect(json['source'], isA<String>().having((s) => s.trim(), 'source', isNotEmpty), reason: f.path);
      }
    }
  });

  test('бренд бисера по умолчанию есть в каталоге', () {
    expect(brandsOf(CatalogMaterial.bead), contains(SettingKeys.defaultBeadBrand.defaultValue));
  });
}
