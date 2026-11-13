import 'package:beading/domain/floss_stock/floss_stock_entry.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:equatable/equatable.dart';

/// Одна нитка списка покупок против запаса: нужно, есть, сколько докупить.
final class FlossShortageLine extends Equatable {
  const FlossShortageLine({required this.purchase, required this.needSkeins, required this.haveSkeins});

  final FlossPurchaseLine purchase;

  /// Нужно мотков (дробное: метры нитки / метры одной нити мотка).
  final double needSkeins;

  /// Есть мотков в запасе; `0`, если нитки в запасе нет.
  final double haveSkeins;

  /// Не хватает мотков, `0`, если запаса достаточно.
  double get shortSkeins => needSkeins > haveSkeins ? needSkeins - haveSkeins : 0;

  /// Целых мотков докупить: «потолок» с относительной поправкой на double.
  int get toBuy {
    final double short = shortSkeins;
    if (short <= 0) return 0;
    final int whole = (short - short * 1e-12).ceil();
    return whole < 1 ? 1 : whole;
  }

  bool get isCovered => toBuy == 0;

  @override
  List<Object?> get props => <Object?>[purchase, needSkeins, haveSkeins];
}

/// Хватает ли запаса на работу и что докупить.
final class FlossShortage extends Equatable {
  FlossShortage._(List<FlossShortageLine> lines) : lines = List<FlossShortageLine>.unmodifiable(lines);

  /// Сравнивает список покупок [purchases] с запасом [stock] (по бренду и номеру). С [withReserve] нужно считается
  /// по метрам с запасом.
  factory FlossShortage.compute(
    List<FlossPurchaseLine> purchases,
    List<FlossStockEntry> stock, {
    bool withReserve = false,
  }) {
    final Map<Object, double> have = <Object, double>{for (final FlossStockEntry e in stock) e.ref: e.skeins};
    return FlossShortage._(<FlossShortageLine>[
      for (final FlossPurchaseLine p in purchases)
        FlossShortageLine(
          purchase: p,
          needSkeins: (withReserve ? p.strandMetersWithReserve : p.strandMeters) / FlossEstimator.skeinStrandMeters,
          haveSkeins: have[p.ref] ?? 0,
        ),
    ]);
  }

  /// По одной на нитку списка покупок, в его порядке.
  final List<FlossShortageLine> lines;

  /// Нитки, которых не хватает.
  List<FlossShortageLine> get shoppingLines => lines.where((l) => !l.isCovered).toList(growable: false);

  int get missingCount => shoppingLines.length;

  /// Всего мотков докупить.
  int get totalToBuy => lines.fold(0, (sum, l) => sum + l.toBuy);

  bool get isCovered => missingCount == 0;

  @override
  List<Object?> get props => <Object?>[lines];
}
