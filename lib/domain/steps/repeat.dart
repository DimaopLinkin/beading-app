import 'package:equatable/equatable.dart';

/// Сколько раз повторить шаг или секцию: заданное число раз или «до нужной длины» (счёт неизвестен заранее).
final class Repeat extends Equatable {
  /// [count] не меньше 1.
  const Repeat.times(int this.count) : assert(count >= 1, 'повтор меньше 1');

  const Repeat.untilDone() : count = null;

  /// Один проход, без повторов.
  static const Repeat once = Repeat.times(1);

  /// Число проходов; `null` у «до нужной длины».
  final int? count;

  bool get isUntilDone => count == null;

  /// Сколько проходов входит в расчёт готовности и материалов: «до нужной длины» считается один раз.
  int get passes => count ?? 1;

  @override
  List<Object?> get props => <Object?>[count];
}
