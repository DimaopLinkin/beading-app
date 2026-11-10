import 'package:beading/core/clock.dart';

/// Считает подряд идущие нажатия на секретное место («О приложении», логотип).
///
/// Серия сбрасывается, если между нажатиями прошло больше [gap]. Седьмое нажатие серии возвращает `true`,
/// после чего счёт начинается заново.
class SecretTapDetector {
  SecretTapDetector({required Clock clock, this.taps = 7, this.gap = const Duration(seconds: 2)}) : _clock = clock;

  final Clock _clock;
  final int taps;
  final Duration gap;

  int _count = 0;
  DateTime? _last;

  /// Регистрирует нажатие; `true`, если серия дошла до [taps].
  bool register() {
    final DateTime now = _clock.now();
    final DateTime? last = _last;
    _count = (last != null && now.difference(last) <= gap) ? _count + 1 : 1;
    _last = now;
    if (_count >= taps) {
      _count = 0;
      _last = null;
      return true;
    }
    return false;
  }
}
