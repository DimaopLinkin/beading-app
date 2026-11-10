import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Позиция каталога и расстояние ΔE2000 до искомого цвета.
final class ColorMatch<T> extends Equatable {
  const ColorMatch(this.item, this.deltaE);

  final T item;
  final double deltaE;

  @override
  List<Object?> get props => <Object?>[item, deltaE];
}

/// Подбор ближайших цветов каталога по ΔE2000. Lab каталога считается один раз.
final class NearestColorMatcher<T> {
  NearestColorMatcher(Iterable<T> catalog, {required Rgb Function(T item) rgbOf})
    : _entries = <(T, Lab)>[for (final T item in catalog) (item, Lab.fromRgb(rgbOf(item)))];

  final List<(T, Lab)> _entries;

  /// До [count] ближайших, по возрастанию ΔE; при равенстве — в порядке каталога.
  List<ColorMatch<T>> nearest(Rgb target, {int count = 5}) {
    if (count <= 0) {
      return <ColorMatch<T>>[];
    }
    final Lab lab = Lab.fromRgb(target);
    final List<ColorMatch<T>> all = <ColorMatch<T>>[
      for (final (T item, Lab itemLab) in _entries) ColorMatch<T>(item, deltaE2000(lab, itemLab)),
    ];
    // Сортировка в Dart устойчива не гарантированно — порядок каталога добавляем явным ключом.
    final List<int> order = List<int>.generate(all.length, (i) => i)
      ..sort((a, b) {
        final int byDelta = all[a].deltaE.compareTo(all[b].deltaE);
        return byDelta != 0 ? byDelta : a.compareTo(b);
      });
    return <ColorMatch<T>>[for (final int i in order.take(count)) all[i]];
  }
}
