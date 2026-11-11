import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Что с одним цветом палитры сделал пересчёт.
final class RecolorMatch extends Equatable {
  const RecolorMatch({required this.index, required this.from, required this.to, required this.deltaE});

  /// Позиция цвета в палитре (с 0).
  final int index;
  final List<CatalogRef> from;
  final List<CatalogRef> to;

  /// Худшее ΔE2000 среди ниток цвета: насколько новая позиция отличается от прежней.
  final double deltaE;

  @override
  List<Object?> get props => <Object?>[index, from, to, deltaE];
}

/// Новая палитра и отчёт по каждому цвету.
final class RecolorResult extends Equatable {
  const RecolorResult({required this.palette, required this.matches});

  final PaletteSnapshot palette;
  final List<RecolorMatch> matches;

  /// Худшее ΔE2000 по всей палитре (0 для пустой).
  double get maxDeltaE => matches.fold<double>(0, (worst, m) => m.deltaE > worst ? m.deltaE : worst);

  @override
  List<Object?> get props => <Object?>[palette, matches];
}

/// «Пересчитать в другой бренд»: каждая позиция палитры заменяется ближайшей по ΔE2000 позицией [brand].
///
/// Соответствие считаем сами, а не берём из «официальных таблиц» ([docs/cross-stitch.md]). Порядок цветов и символы
/// сохраняются, так что сетка остаётся прежней; два цвета могут оказаться на одной позиции — решает пользовательница.
/// Смешанная нить пересчитывается по ниткам. Цвета не из каталога подбираются по своему RGB.
final class RecolorPalette {
  const RecolorPalette(this._catalog, {this.material = CatalogMaterial.floss});

  final CatalogRepository _catalog;
  final CatalogMaterial material;

  Future<Result<RecolorResult>> call(PaletteSnapshot palette, {required String brand}) async {
    final Result<List<CatalogColor>> all = await _catalog.search(material: material, brand: brand);
    final List<CatalogColor>? target = all.valueOrNull;
    if (target == null) {
      return Err<RecolorResult>(all.failureOrNull!);
    }
    if (target.isEmpty) {
      return Err<RecolorResult>(ValidationFailure('В каталоге нет бренда $brand'));
    }
    final NearestColorMatcher<CatalogColor> matcher = NearestColorMatcher<CatalogColor>(
      target,
      rgbOf: (c) => c.rgb,
    );
    final List<PatternColor> colors = <PatternColor>[];
    final List<RecolorMatch> matches = <RecolorMatch>[];
    for (final (int index, PatternColor color) in palette.colors.indexed) {
      final List<Rgb> sources = <Rgb>[];
      for (final CatalogRef ref in color.components) {
        final Result<CatalogColor?> found = await _catalog.find(ref.brand, ref.code);
        if (found.failureOrNull != null) {
          return Err<RecolorResult>(found.failureOrNull!);
        }
        sources.add(found.valueOrNull?.rgb ?? color.rgb);
      }
      final List<ColorMatch<CatalogColor>> picked = <ColorMatch<CatalogColor>>[
        for (final Rgb source in sources) matcher.nearest(source, count: 1).first,
      ];
      final List<CatalogColor> chosen = <CatalogColor>[for (final m in picked) m.item];
      colors.add(
        PatternColor(
          rgb: Rgb.average(<Rgb>[for (final CatalogColor c in chosen) c.rgb]),
          name: chosen.map((c) => c.name).join(' + '),
          components: <CatalogRef>[for (final CatalogColor c in chosen) c.ref],
          finish: color.finish,
          symbol: color.symbol,
        ),
      );
      matches.add(
        RecolorMatch(
          index: index,
          from: color.components,
          to: <CatalogRef>[for (final CatalogColor c in chosen) c.ref],
          deltaE: picked.map((m) => m.deltaE).reduce((a, b) => a > b ? a : b),
        ),
      );
    }
    return Success<RecolorResult>(
      RecolorResult(palette: PaletteSnapshot(colors), matches: List<RecolorMatch>.unmodifiable(matches)),
    );
  }
}
