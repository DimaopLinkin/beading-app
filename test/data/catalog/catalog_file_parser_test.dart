import 'dart:convert';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/catalog/catalog_file_parser.dart';
import 'package:beading/domain/catalog/catalog_file.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> valid() => <String, Object?>{
  'version': 1,
  'material': 'bead',
  'brand': 'Miyuki',
  'series': 'Delica',
  'sizeCode': '11/0',
  'colors': <Object?>[
    <String, Object?>{'code': 'DB0010', 'name': 'Black', 'rgb': '#111111', 'finish': 'opaque'},
    <String, Object?>{'code': 'DB0011', 'name': 'Red', 'rgb': 'ff0000'},
  ],
};

String message(Result<CatalogFile> r) => (r.failureOrNull! as ValidationFailure).message;

void main() {
  test('разбирает корректный файл', () {
    final CatalogFile file = parseCatalogFile('miyuki_delica_11', jsonEncode(valid())).valueOrNull!;
    expect(file.id, 'miyuki_delica_11');
    expect(file.material, CatalogMaterial.bead);
    expect(file.colors, hasLength(2));
    expect(file.colors.first.finish, 'opaque');
    expect(file.colors.last.finish, isNull);
    expect(file.colors.first.sizeCode, '11/0');
    expect(file.colors.first.id, 'bead|Miyuki|Delica|11/0|DB0010');
  });

  group('ошибки', () {
    void expectFailure(String name, void Function(Map<String, Object?> m) mutate, String fragment) {
      test(name, () {
        final Map<String, Object?> m = valid();
        mutate(m);
        final Result<CatalogFile> r = parseCatalogFile('f', jsonEncode(m));
        expect(r.isFailure, isTrue);
        expect(message(r), allOf(contains('f'), contains(fragment)));
      });
    }

    expectFailure('sizeCode не строка', (m) => m['sizeCode'] = 11, 'sizeCode');
    expectFailure(
      'finish не строка',
      (m) => (m['colors']! as List<Object?>).add(<String, Object?>{
        'code': 'A',
        'name': 'x',
        'rgb': '#000000',
        'finish': 3,
      }),
      'finish',
    );
    expectFailure('нет version', (m) => m.remove('version'), 'version');
    expectFailure('неизвестный материал', (m) => m['material'] = 'wood', 'material');
    expectFailure('нет бренда', (m) => m.remove('brand'), 'brand');
    expectFailure('бисер без размера', (m) => m.remove('sizeCode'), 'sizeCode');
    expectFailure('пустой список', (m) => m['colors'] = <Object?>[], 'colors');
    expectFailure('цвет не объект', (m) => m['colors'] = <Object?>['x'], 'colors[0]');
    expectFailure(
      'нет name',
      (m) => (m['colors']! as List<Object?>).add(<String, Object?>{'code': 'A', 'rgb': '#000000'}),
      'name',
    );
    expectFailure(
      'плохой rgb',
      (m) => (m['colors']! as List<Object?>).add(<String, Object?>{'code': 'A', 'name': 'x', 'rgb': '#12'}),
      'rgb',
    );
    expectFailure(
      'дубль артикула в другой записи (DB-10 == DB0010)',
      (m) => (m['colors']! as List<Object?>).add(<String, Object?>{'code': 'DB-10', 'name': 'x', 'rgb': '#000000'}),
      'повторяющийся',
    );
  });

  test('не JSON и не объект', () {
    expect(parseCatalogFile('f', '{oops').isFailure, isTrue);
    expect(parseCatalogFile('f', '[]').isFailure, isTrue);
  });

  test('нитки не требуют размера', () {
    final Map<String, Object?> m = valid()
      ..['material'] = 'floss'
      ..remove('sizeCode');
    final CatalogFile file = parseCatalogFile('f', jsonEncode(m)).valueOrNull!;
    expect(file.colors.first.sizeCode, isNull);
  });
}
