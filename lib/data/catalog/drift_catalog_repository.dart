import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/catalog_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/catalog/code_search_key.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Каталог поверх `catalog_colors`. Каталог небольшой (тысячи строк), поэтому фильтрация по тексту — в Dart:
/// так одинаково работают «ё/е», регистр и ведущие нули в артикулах.
class DriftCatalogRepository implements CatalogRepository {
  DriftCatalogRepository(this._dao);

  final CatalogDao _dao;

  @override
  Future<Result<List<CatalogColor>>> search({String query = '', CatalogMaterial? material, String? brand}) =>
      guardStorage<List<CatalogColor>>(() async {
        final List<CatalogColor> all = await _load(material: material, brand: brand);
        final String text = _fold(query.trim());
        if (text.isEmpty) {
          return all;
        }
        final String key = codeSearchKey(text);
        final List<String> tokens = text.split(RegExp(r'\s+'));
        final List<CatalogColor> byCode = <CatalogColor>[];
        final List<CatalogColor> byName = <CatalogColor>[];
        for (final CatalogColor c in all) {
          final String codeKey = codeSearchKey(c.code);
          // «10» находит DB0010, «45» — 45A и 45F (буква отделки на конце не мешает).
          final String core = numericPart(codeKey);
          if (key.isNotEmpty && (codeKey == key || core == key || core.replaceFirst(_trailingLetters, '') == key)) {
            byCode.add(c);
          } else {
            final String name = _fold(c.name);
            if (tokens.every(name.contains)) {
              byName.add(c);
            }
          }
        }
        return <CatalogColor>[...byCode, ...byName];
      });

  @override
  Future<Result<List<String>>> brands(CatalogMaterial material) =>
      guardStorage<List<String>>(() => _dao.brandsOf(material.wire));

  @override
  Future<Result<CatalogColor?>> find(String brand, String code) => guardStorage<CatalogColor?>(() async {
    final String key = codeSearchKey(code);
    for (final CatalogColor c in await _load(brand: brand)) {
      if (codeSearchKey(c.code) == key) {
        return c;
      }
    }
    return null;
  });

  @override
  Future<Result<List<ColorMatch<CatalogColor>>>> nearest(
    Rgb target, {
    required CatalogMaterial material,
    String? brand,
    int count = 5,
  }) => guardStorage<List<ColorMatch<CatalogColor>>>(() async {
    final List<CatalogColor> items = await _load(material: material, brand: brand);
    return NearestColorMatcher<CatalogColor>(items, rgbOf: (c) => c.rgb).nearest(target, count: count);
  });

  /// В порядке: бренд, серия, размер, артикул «по-человечески» (DB2 перед DB10).
  Future<List<CatalogColor>> _load({CatalogMaterial? material, String? brand}) async {
    final List<CatalogColorRow> rows = await _dao.rows(material: material?.wire, brand: brand);
    final List<CatalogColor> colors = <CatalogColor>[
      for (final CatalogColorRow r in rows)
        if (CatalogMaterial.fromWire(r.material) != null)
          CatalogColor(
            material: CatalogMaterial.fromWire(r.material)!,
            brand: r.brand,
            series: r.series,
            code: r.code,
            name: r.name,
            rgb: Rgb((r.rgb >> 16) & 0xFF, (r.rgb >> 8) & 0xFF, r.rgb & 0xFF),
            finish: r.finish,
            sizeCode: r.sizeCode,
          ),
    ];
    colors.sort((a, b) {
      final int byBrand = a.brand.compareTo(b.brand);
      if (byBrand != 0) {
        return byBrand;
      }
      final int bySeries = a.series.compareTo(b.series);
      if (bySeries != 0) {
        return bySeries;
      }
      final int bySize = (a.sizeCode ?? '').compareTo(b.sizeCode ?? '');
      return bySize != 0 ? bySize : _compareCodes(a.code, b.code);
    });
    return colors;
  }

  static String _fold(String s) => s.toLowerCase().replaceAll('ё', 'е');

  static int _compareCodes(String a, String b) {
    final RegExpMatch? ma = _codePattern.firstMatch(codeSearchKey(a));
    final RegExpMatch? mb = _codePattern.firstMatch(codeSearchKey(b));
    if (ma == null || mb == null) {
      return a.compareTo(b);
    }
    final int byPrefix = ma[1]!.compareTo(mb[1]!);
    if (byPrefix != 0) {
      return byPrefix;
    }
    // Числа любой длины: сначала по длине (ведущих нулей нет), затем по цифрам.
    final int byNumber = ma[2]!.length != mb[2]!.length
        ? ma[2]!.length.compareTo(mb[2]!.length)
        : ma[2]!.compareTo(mb[2]!);
    return byNumber != 0 ? byNumber : ma[3]!.compareTo(mb[3]!);
  }

  static final RegExp _trailingLetters = RegExp(r'[a-zа-яё]+$');

  static final RegExp _codePattern = RegExp(r'^([^0-9]*)(\d*)(.*)$');
}
