import 'dart:convert';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_file.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/code_search_key.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Разбирает и проверяет JSON-файл каталога. Любая ошибка формата — [ValidationFailure] с указанием файла.
Result<CatalogFile> parseCatalogFile(String id, String json) {
  try {
    final Object? root = jsonDecode(json);
    if (root is! Map<String, Object?>) {
      return _fail(id, 'корень должен быть объектом');
    }
    final Object? version = root['version'];
    if (version is! int || version < 1) {
      return _fail(id, '`version` — целое число от 1');
    }
    final String? materialWire = _string(root, 'material');
    final CatalogMaterial? material = materialWire == null ? null : CatalogMaterial.fromWire(materialWire);
    if (material == null) {
      return _fail(id, '`material` — bead или floss');
    }
    final String? brand = _string(root, 'brand');
    final String? series = _string(root, 'series');
    if (brand == null || series == null) {
      return _fail(id, '`brand` и `series` обязательны');
    }
    if (root.containsKey('sizeCode') && root['sizeCode'] is! String) {
      return _fail(id, '`sizeCode` — строка');
    }
    final String? sizeCode = root['sizeCode'] is String ? (root['sizeCode']! as String).trim() : null;
    if (material == CatalogMaterial.bead && (sizeCode == null || sizeCode.isEmpty)) {
      return _fail(id, 'у бисера обязателен `sizeCode`');
    }
    final Object? rawColors = root['colors'];
    if (rawColors is! List<Object?> || rawColors.isEmpty) {
      return _fail(id, '`colors` — непустой список');
    }
    final Set<String> seenKeys = <String>{};
    final List<CatalogColor> colors = <CatalogColor>[];
    for (final (int index, Object? item) in rawColors.indexed) {
      if (item is! Map<String, Object?>) {
        return _fail(id, 'colors[$index]: ожидался объект');
      }
      final String? code = _string(item, 'code');
      final String? name = _string(item, 'name');
      final String? hex = _string(item, 'rgb');
      if (code == null || name == null || hex == null) {
        return _fail(id, 'colors[$index]: нужны `code`, `name`, `rgb`');
      }
      final Rgb rgb;
      try {
        rgb = Rgb.fromHex(hex);
      } on FormatException {
        return _fail(id, 'colors[$index] ($code): некорректный rgb "$hex"');
      }
      if (!seenKeys.add(codeSearchKey(code))) {
        return _fail(id, 'повторяющийся артикул $code');
      }
      if (item.containsKey('finish') && item['finish'] is! String) {
        return _fail(id, 'colors[$index] ($code): `finish` — строка');
      }
      final String? finish = _string(item, 'finish');
      colors.add(
        CatalogColor(
          material: material,
          brand: brand,
          series: series,
          code: code,
          name: name,
          rgb: rgb,
          finish: finish,
          sizeCode: sizeCode == null || sizeCode.isEmpty ? null : sizeCode,
        ),
      );
    }
    return Success<CatalogFile>(
      CatalogFile(
        id: id,
        version: version,
        material: material,
        brand: brand,
        series: series,
        sizeCode: sizeCode == null || sizeCode.isEmpty ? null : sizeCode,
        colors: List<CatalogColor>.unmodifiable(colors),
      ),
    );
  } on FormatException catch (error) {
    return _fail(id, 'не JSON: ${error.message}');
  }
}

String? _string(Map<String, Object?> map, String key) {
  final Object? value = map[key];
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Result<CatalogFile> _fail(String id, String reason) => Err<CatalogFile>(ValidationFailure('Каталог $id: $reason'));
