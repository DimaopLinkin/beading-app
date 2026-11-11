import 'dart:math' as math;

import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/materials/material_estimate.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';
import 'package:equatable/equatable.dart';

/// Расход мулине одного цвета схемы.
///
/// Длины — в метрах одной нити (одного сложения): ниже длина в иголке умножается на число сложений. Моток мулине —
/// 8 м из 6 сложений, то есть 48 м одной нити.
final class FlossMaterialLine extends Equatable implements MaterialLine {
  const FlossMaterialLine({
    required this.colorIndex,
    required this.color,
    required this.crossStitches,
    required this.partialStitches,
    required this.backstitchCells,
    required this.knots,
    required this.strandMeters,
    required this.strandMetersWithReserve,
    required this.skeins,
    required this.skeinsWithReserve,
  });

  @override
  final int colorIndex;

  @override
  final PatternColor color;

  /// Полных крестиков в сетке.
  final int crossStitches;

  /// Неполных крестиков (½, ¼, ¾, петит, гобелен) этого цвета, штук.
  final int partialStitches;

  /// Длина бэкстича и прямых стежков, в клетках.
  final double backstitchCells;

  /// Узелков.
  final int knots;

  /// Нитки на цвет, метры одной нити.
  final double strandMeters;

  /// Нитки на цвет с запасом, метры одной нити.
  final double strandMetersWithReserve;

  /// Мотков, если считать цвет отдельно (для смешанной нити — условно, покупают по списку [FlossEstimate.purchases]).
  final int skeins;

  /// Мотков с запасом.
  final int skeinsWithReserve;

  /// Смешанная нить: две нитки в одной иголке.
  bool get isBlend => color.components.length > 1;

  @override
  List<Object?> get props => <Object?>[
    colorIndex,
    color,
    crossStitches,
    partialStitches,
    backstitchCells,
    knots,
    strandMeters,
    strandMetersWithReserve,
    skeins,
    skeinsWithReserve,
  ];
}

/// Список покупок: одна нитка каталога (бренд и номер) и сколько мотков брать.
///
/// Смешанные нити раскладываются по составляющим, а одинаковые нитки разных цветов схемы складываются: моток
/// покупают один на всех.
final class FlossPurchaseLine extends Equatable {
  const FlossPurchaseLine({
    required this.ref,
    required this.rgb,
    required this.name,
    required this.strandMeters,
    required this.strandMetersWithReserve,
    required this.skeins,
    required this.skeinsWithReserve,
  });

  final CatalogRef ref;

  /// Цвет образца: у смешанной нити — среднее двух ниток, если нитка не встречается в схеме отдельным цветом.
  final Rgb rgb;

  /// Название цвета схемы, если нитка стоит в ней отдельно; иначе `null`.
  final String? name;

  final double strandMeters;
  final double strandMetersWithReserve;
  final int skeins;
  final int skeinsWithReserve;

  @override
  List<Object?> get props => <Object?>[
    ref,
    rgb,
    name,
    strandMeters,
    strandMetersWithReserve,
    skeins,
    skeinsWithReserve,
  ];
}

/// Сколько канвы взять под схему: размер вышивки и размер куска с полями.
final class FabricNeed extends Equatable {
  const FabricNeed({required this.stitchedWidthCm, required this.stitchedHeightCm, required this.marginCm});

  final double stitchedWidthCm;
  final double stitchedHeightCm;

  /// Поле с каждой стороны, см.
  final double marginCm;

  double get widthCm => stitchedWidthCm + 2 * marginCm;
  double get heightCm => stitchedHeightCm + 2 * marginCm;

  @override
  List<Object?> get props => <Object?>[stitchedWidthCm, stitchedHeightCm, marginCm];
}

/// Расход мулине на схему: по цветам, список покупок по ниткам и канва.
final class FlossEstimate extends Equatable implements MaterialEstimate {
  FlossEstimate({
    required this.fabric,
    required this.fabricNeed,
    required this.reserve,
    required List<FlossMaterialLine> lines,
    required List<FlossPurchaseLine> purchases,
  }) : lines = List<FlossMaterialLine>.unmodifiable(lines),
       purchases = List<FlossPurchaseLine>.unmodifiable(purchases);

  final Fabric fabric;
  final FabricNeed fabricNeed;

  @override
  final double reserve;

  @override
  final List<FlossMaterialLine> lines;

  /// Нитки каталога по возрастанию бренда и номера (номера как строки, числа по значению).
  final List<FlossPurchaseLine> purchases;

  int get totalCrossStitches => lines.fold(0, (sum, l) => sum + l.crossStitches);

  /// Всего мотков в списке покупок.
  int get totalSkeins => purchases.fold(0, (sum, l) => sum + l.skeins);

  /// Всего мотков в списке покупок с запасом.
  int get totalSkeinsWithReserve => purchases.fold(0, (sum, l) => sum + l.skeinsWithReserve);

  @override
  List<Object?> get props => <Object?>[fabric, fabricNeed, reserve, lines, purchases];
}

/// Расход мулине: крестики, неполные крестики, бэкстич и узелки по сложениям, запас, мотки и канва.
///
/// Коэффициенты — приближение из [docs/cross-stitch.md](../../../docs/cross-stitch.md) (раздел 5.3): точность «до
/// мотка», не до сантиметра.
final class FlossEstimator implements MaterialEstimator {
  FlossEstimator({
    required this.fabric,
    required this.layers,
    this.reserve = defaultReserve,
    this.crossThreadFactor = defaultCrossThreadFactor,
    this.backstitchThreadFactor = defaultBackstitchThreadFactor,
    this.fabricMarginCm = defaultFabricMarginCm,
  }) {
    if (!reserve.isFinite || reserve < 0 || reserve > 1) {
      throw ArgumentError.value(reserve, 'reserve', 'доля от 0 до 1');
    }
    if (!crossThreadFactor.isFinite || crossThreadFactor <= 0) {
      throw ArgumentError.value(crossThreadFactor, 'crossThreadFactor', 'положительное число');
    }
    if (!backstitchThreadFactor.isFinite || backstitchThreadFactor <= 0) {
      throw ArgumentError.value(backstitchThreadFactor, 'backstitchThreadFactor', 'положительное число');
    }
    if (!fabricMarginCm.isFinite || fabricMarginCm < 0) {
      throw ArgumentError.value(fabricMarginCm, 'fabricMarginCm', 'не меньше нуля');
    }
  }

  /// Запас по умолчанию: +10%.
  static const double defaultReserve = 0.1;

  /// Нитки на полный крестик в размерах клетки: два диагональных стежка и переходы с изнанки.
  static const double defaultCrossThreadFactor = 7;

  /// Нитки на единицу длины бэкстича: стежок идёт по лицу и возвращается по изнанке.
  static const double defaultBackstitchThreadFactor = 2;

  /// Поле канвы с каждой стороны, см: на оправу и край.
  static const double defaultFabricMarginCm = 5;

  /// Длина мотка мулине, метры.
  static const double skeinMeters = 8;

  /// Сложений в мотке.
  static const int skeinStrands = 6;

  /// Метров одной нити в мотке.
  static const double skeinStrandMeters = skeinMeters * skeinStrands;

  /// Вес неполного крестика в долях полного.
  static double partialWeight(PartialKind kind) => switch (kind) {
    PartialKind.half => 0.5,
    PartialKind.quarter => 0.25,
    PartialKind.threeQuarter => 0.75,
    PartialKind.petit => 0.25,
    PartialKind.tent => 0.5,
  };

  /// Нитки на узелок в размерах клетки: основа плюс обороты.
  static double knotCells(int wraps) => 2.0 + wraps;

  final Fabric fabric;
  final StitchLayers layers;
  final double reserve;
  final double crossThreadFactor;
  final double backstitchThreadFactor;
  final double fabricMarginCm;

  @override
  FlossEstimate estimate(Grid grid, PaletteSnapshot palette) {
    if (layers.columns != grid.width || layers.rows != grid.height) {
      throw ArgumentError('Слои ${layers.columns}×${layers.rows} не совпадают с сеткой ${grid.width}×${grid.height}');
    }
    final int size = palette.length + 1;
    final List<int> crosses = List<int>.filled(size, 0);
    final List<double> partialEquivalents = List<double>.filled(size, 0);
    final List<int> partials = List<int>.filled(size, 0);
    final List<double> backCells = List<double>.filled(size, 0);
    final List<double> knotCellSums = List<double>.filled(size, 0);
    final List<int> knots = List<int>.filled(size, 0);

    void requireColor(int value) {
      if (value > palette.length) {
        throw ArgumentError('В схеме цвет $value, а в палитре ${palette.length} цветов');
      }
    }

    for (final int value in grid.cells) {
      if (value == 0) continue;
      requireColor(value);
      crosses[value]++;
    }
    for (final PartialStitch p in layers.partials) {
      requireColor(p.color);
      partials[p.color]++;
      partialEquivalents[p.color] += partialWeight(p.kind);
    }
    for (final LineStitch l in layers.lines) {
      requireColor(l.color);
      final int dx = l.to.x - l.from.x;
      final int dy = l.to.y - l.from.y;
      // Узлы решётки стоят через полклетки.
      backCells[l.color] += math.sqrt((dx * dx + dy * dy).toDouble()) / 2;
    }
    for (final PointStitch p in layers.points) {
      if (p.kind == PointKind.bead) continue;
      requireColor(p.color);
      knots[p.color]++;
      knotCellSums[p.color] += knotCells(p.wraps);
    }

    final double cellMm = fabric.widthMm;
    final List<FlossMaterialLine> lines = <FlossMaterialLine>[];
    final Map<CatalogRef, _Purchase> purchases = <CatalogRef, _Purchase>{};
    for (int value = 1; value <= palette.length; value++) {
      if (crosses[value] == 0 && partials[value] == 0 && backCells[value] == 0 && knots[value] == 0) continue;
      final PatternColor color = palette.colors[value - 1];
      final StitchSpec spec = layers.specFor(value);
      final double mm =
          (crosses[value] + partialEquivalents[value]) * crossThreadFactor * cellMm * spec.crossStrands +
          backCells[value] * backstitchThreadFactor * cellMm * spec.backstitchStrands +
          knotCellSums[value] * cellMm * spec.crossStrands;
      final double meters = mm / 1000;
      lines.add(
        FlossMaterialLine(
          colorIndex: value,
          color: color,
          crossStitches: crosses[value],
          partialStitches: partials[value],
          backstitchCells: backCells[value],
          knots: knots[value],
          strandMeters: meters,
          strandMetersWithReserve: meters * (1 + reserve),
          skeins: _skeins(meters, 0),
          skeinsWithReserve: _skeins(meters, reserve),
        ),
      );
      // Сложения делятся поровну между нитками смешанной нити.
      final double share = meters / color.components.length;
      for (final CatalogRef ref in color.components) {
        final _Purchase purchase = purchases.putIfAbsent(ref, () => _Purchase(color.rgb));
        purchase.meters += share;
        if (color.components.length == 1) {
          purchase
            ..rgb = color.rgb
            ..name = color.name;
        }
      }
    }
    final List<CatalogRef> refs = purchases.keys.toList()..sort(_compareRefs);
    return FlossEstimate(
      fabric: fabric,
      fabricNeed: FabricNeed(
        stitchedWidthCm: fabric.cmForCells(grid.width),
        stitchedHeightCm: fabric.cmForCells(grid.height),
        marginCm: fabricMarginCm,
      ),
      reserve: reserve,
      lines: lines,
      purchases: <FlossPurchaseLine>[
        for (final CatalogRef ref in refs)
          FlossPurchaseLine(
            ref: ref,
            rgb: purchases[ref]!.rgb,
            name: purchases[ref]!.name,
            strandMeters: purchases[ref]!.meters,
            strandMetersWithReserve: purchases[ref]!.meters * (1 + reserve),
            skeins: _skeins(purchases[ref]!.meters, 0),
            skeinsWithReserve: _skeins(purchases[ref]!.meters, reserve),
          ),
      ],
    );
  }

  /// Мотков: «потолок» с относительной поправкой, чтобы ровные 48 м не давали лишний моток из-за double.
  static int _skeins(double strandMeters, double reserve) {
    if (strandMeters <= 0) return 0;
    final double exact = strandMeters * (1 + reserve) / skeinStrandMeters;
    return math.max(1, (exact - exact * 1e-12).ceil());
  }

  /// Бренд по алфавиту, номер: числа по значению («310» раньше «3721»), остальное по тексту.
  static int _compareRefs(CatalogRef a, CatalogRef b) {
    final int byBrand = a.brand.compareTo(b.brand);
    if (byBrand != 0) return byBrand;
    final int? x = int.tryParse(a.code);
    final int? y = int.tryParse(b.code);
    if (x != null && y != null && x != y) return x.compareTo(y);
    if (x != null && y == null) return -1;
    if (x == null && y != null) return 1;
    return a.code.compareTo(b.code);
  }
}

final class _Purchase {
  _Purchase(this.rgb);

  Rgb rgb;
  String? name;
  double meters = 0;
}
