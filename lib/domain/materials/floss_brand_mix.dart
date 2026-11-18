import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:equatable/equatable.dart';

/// Из каких брендов собраны нитки схемы (T86): основной и добранные у других производителей.
///
/// Нужен только когда брендов больше одного ([FlossBrandMix.of] иначе даёт `null`): тогда рядом с ниткой показывают
/// её бренд, а в шапке списка закупки и PDF пишут сводку.
final class FlossBrandMix extends Equatable {
  const FlossBrandMix({required this.main, required this.mainThreads, required this.foreign});

  /// Бренд, которого в схеме больше всего ниток; при равенстве — первый по алфавиту.
  final String main;

  /// Сколько ниток основного бренда (T89).
  final int mainThreads;

  /// Остальные бренды и число их ниток: больше ниток раньше, при равенстве по алфавиту. Не пуст.
  final Map<String, int> foreign;

  /// Бренды добранных ниток в порядке [foreign].
  List<String> get foreignBrands => foreign.keys.toList();

  /// Всего ниток не основного бренда.
  int get foreignThreads => foreign.values.fold(0, (sum, n) => sum + n);

  /// Разбор по [threads]; повторы одной нитки считаются один раз. `null`, если брендов не больше одного.
  static FlossBrandMix? of(Iterable<CatalogRef> threads) {
    final Map<String, int> counts = <String, int>{};
    for (final CatalogRef ref in threads.toSet()) {
      counts.update(ref.brand, (n) => n + 1, ifAbsent: () => 1);
    }
    if (counts.length < 2) return null;
    final List<MapEntry<String, int>> sorted = counts.entries.toList()
      ..sort((a, b) => a.value != b.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    return FlossBrandMix(
      main: sorted.first.key,
      mainThreads: sorted.first.value,
      foreign: <String, int>{for (final MapEntry<String, int> e in sorted.skip(1)) e.key: e.value},
    );
  }

  @override
  List<Object?> get props => <Object?>[main, mainThreads, foreign];
}
