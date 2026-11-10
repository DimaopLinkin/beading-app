import 'dart:math';

import 'package:beading/core/clock.dart';

/// Генератор идентификаторов сущностей.
abstract interface class IdGenerator {
  String next();
}

/// UUID версии 7 (RFC 9562): 48 бит времени в мс, 12 бит счётчика, 62 бита случайности.
///
/// Значения строго возрастают, даже в одну миллисекунду и если часы откатились назад.
class UuidV7IdGenerator implements IdGenerator {
  UuidV7IdGenerator({Clock clock = const SystemClock(), Random? random})
    : _clock = clock,
      _random = random ?? Random.secure();

  static const int _counterLimit = 0x1000;

  final Clock _clock;
  final Random _random;

  int _lastMillis = -1;
  int _counter = 0;

  @override
  String next() {
    final int now = _clock.now().millisecondsSinceEpoch;
    if (now > _lastMillis) {
      _lastMillis = now;
      // Верхняя половина диапазона не используется: запас под приращения внутри миллисекунды.
      _counter = _random.nextInt(_counterLimit ~/ 2);
    } else {
      _counter++;
      if (_counter >= _counterLimit) {
        _lastMillis++;
        _counter = 0;
      }
    }

    final StringBuffer hex = StringBuffer()
      ..write(_lastMillis.toRadixString(16).padLeft(12, '0'))
      ..write((0x7000 | _counter).toRadixString(16))
      ..write((0x8000 | _random.nextInt(0x4000)).toRadixString(16))
      ..write(_randomHex(12));
    final String h = hex.toString();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  String _randomHex(int length) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(_random.nextInt(16).toRadixString(16));
    }
    return buffer.toString();
  }
}
