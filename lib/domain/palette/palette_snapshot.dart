import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/symbol_assigner.dart';
import 'package:equatable/equatable.dart';

/// Карта переиндексации значений сетки после правки палитры.
///
/// Значение сетки: `0` — пусто, `n` — цвет `palette[n - 1]`. Не знает про `Grid`: сетку переписывает вызывающий.
final class PaletteReindex extends Equatable {
  PaletteReindex(Map<int, int> changes) : _changes = Map<int, int>.unmodifiable(changes);

  const PaletteReindex.identity() : _changes = const <int, int>{};

  /// Только изменившиеся значения: старое → новое (`0` — ячейка очищается).
  final Map<int, int> _changes;

  Map<int, int> get changes => _changes;

  bool get isIdentity => _changes.isEmpty;

  int apply(int gridValue) => _changes[gridValue] ?? gridValue;

  @override
  List<Object?> get props => <Object?>[_changes];
}

/// Результат правки палитры.
final class PaletteEdit extends Equatable {
  const PaletteEdit({required this.palette, required this.reindex, this.gridValue});

  final PaletteSnapshot palette;
  final PaletteReindex reindex;

  /// Значение сетки добавленного цвета (только для `add`).
  final int? gridValue;

  @override
  List<Object?> get props => <Object?>[palette, reindex, gridValue];
}

/// Палитра схемы: неизменяемый снимок цветов. Правки возвращают [Result] и карту переиндексации.
final class PaletteSnapshot extends Equatable {
  PaletteSnapshot(List<PatternColor> colors) : colors = List<PatternColor>.unmodifiable(colors);

  factory PaletteSnapshot.empty() => PaletteSnapshot(const <PatternColor>[]);

  /// В сетке индекс хранится в `Uint16List`, `0` занят под «пусто».
  static const int maxColors = 65535;

  static const SymbolAssigner _assigner = SymbolAssigner();

  final List<PatternColor> colors;

  int get length => colors.length;

  /// Копия, где мелкие и похожие знаки ([SymbolAssigner.avoided]) заменены первым свободным знаком набора. Нужна
  /// для показа схем, сохранённых с прежним набором; в базу замена не пишется.
  PaletteSnapshot withLegibleSymbols() {
    if (!colors.any((c) => c.symbol != null && SymbolAssigner.avoided.contains(c.symbol))) return this;
    final List<String?> used = colors.map((c) => c.symbol).toList();
    return PaletteSnapshot(<PatternColor>[
      for (int i = 0; i < colors.length; i++)
        if (colors[i].symbol != null && SymbolAssigner.avoided.contains(colors[i].symbol))
          () {
            final String? next = _assigner.next(used);
            if (next == null) return colors[i];
            used[i] = next;
            return colors[i].copyWith(symbol: next);
          }()
        else
          colors[i],
    ]);
  }

  /// Цвет по значению сетки (с 1); `null` для `0` и значений вне палитры.
  PatternColor? colorAt(int gridValue) => _valid(gridValue) ? colors[gridValue - 1] : null;

  bool _valid(int gridValue) => gridValue >= 1 && gridValue <= colors.length;

  Result<PaletteEdit> add(PatternColor color) {
    if (colors.length >= maxColors) {
      return const Err<PaletteEdit>(ValidationFailure('Палитра переполнена'));
    }
    final List<String?> used = colors.map((c) => c.symbol).toList();
    final String? symbol = color.symbol ?? _assigner.next(used);
    if (symbol == null) {
      return const Err<PaletteEdit>(ValidationFailure('Закончились символы'));
    }
    if (used.contains(symbol)) {
      return Err<PaletteEdit>(ValidationFailure('Символ $symbol уже занят'));
    }
    final PaletteSnapshot next = PaletteSnapshot(<PatternColor>[...colors, color.copyWith(symbol: symbol)]);
    return Success<PaletteEdit>(
      PaletteEdit(palette: next, reindex: const PaletteReindex.identity(), gridValue: next.length),
    );
  }

  Result<PaletteEdit> rename(int gridValue, String name) {
    if (!_valid(gridValue)) {
      return Err<PaletteEdit>(_outOfRange(gridValue));
    }
    if (name.trim().isEmpty) {
      return const Err<PaletteEdit>(ValidationFailure('Название не может быть пустым'));
    }
    return _replaceAt(gridValue, colors[gridValue - 1].copyWith(name: name.trim()));
  }

  /// Заменяет цвет, компоненты и отделку; символ остаётся прежним.
  Result<PaletteEdit> replace(int gridValue, PatternColor color) {
    if (!_valid(gridValue)) {
      return Err<PaletteEdit>(_outOfRange(gridValue));
    }
    return _replaceAt(gridValue, color.copyWith(symbol: colors[gridValue - 1].symbol));
  }

  Result<PaletteEdit> _replaceAt(int gridValue, PatternColor color) {
    final List<PatternColor> next = <PatternColor>[...colors];
    next[gridValue - 1] = color;
    return Success<PaletteEdit>(PaletteEdit(palette: PaletteSnapshot(next), reindex: const PaletteReindex.identity()));
  }

  /// Удаляет цвет: его ячейки очищаются (`0`), старшие индексы сдвигаются вниз.
  Result<PaletteEdit> remove(int gridValue) {
    if (!_valid(gridValue)) {
      return Err<PaletteEdit>(_outOfRange(gridValue));
    }
    return Success<PaletteEdit>(
      PaletteEdit(
        palette: PaletteSnapshot(<PatternColor>[...colors]..removeAt(gridValue - 1)),
        reindex: PaletteReindex(<int, int>{
          gridValue: 0,
          for (int v = gridValue + 1; v <= colors.length; v++) v: v - 1,
        }),
      ),
    );
  }

  /// Объединяет цвет [from] с [into]: ячейки [from] становятся [into], [from] исчезает из палитры.
  Result<PaletteEdit> merge({required int from, required int into}) {
    if (!_valid(from)) {
      return Err<PaletteEdit>(_outOfRange(from));
    }
    if (!_valid(into)) {
      return Err<PaletteEdit>(_outOfRange(into));
    }
    if (from == into) {
      return const Err<PaletteEdit>(ValidationFailure('Нельзя объединить цвет с самим собой'));
    }
    final int target = into > from ? into - 1 : into;
    return Success<PaletteEdit>(
      PaletteEdit(
        palette: PaletteSnapshot(<PatternColor>[...colors]..removeAt(from - 1)),
        reindex: PaletteReindex(<int, int>{
          from: target,
          for (int v = from + 1; v <= colors.length; v++) v: v - 1,
        }),
      ),
    );
  }

  ValidationFailure _outOfRange(int gridValue) =>
      ValidationFailure('Цвета $gridValue нет в палитре из ${colors.length}');

  @override
  List<Object?> get props => <Object?>[colors];
}
