/// Источник времени. В `lib/` вне `core/` `DateTime.now()` не вызываем.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
