import 'package:equatable/equatable.dart';

enum StatsPeriod { week, month, year, all }

/// Период статистики в местном времени: [start] включительно, [end] не включительно. Границы строятся конструктором
/// `DateTime(...)`, а не прибавлением суток, чтобы переход на летнее время не сдвигал полночь.
final class StatsRange extends Equatable {
  const StatsRange(this.start, this.end);

  /// Всё время: от давнего начала до конца сегодняшнего дня.
  factory StatsRange.all(DateTime now) => StatsRange(DateTime(2000), DateTime(now.year, now.month, now.day + 1));

  /// Период, содержащий [now], сдвинутый на [offset] периодов (отрицательный — назад). [weekStart] — `DateTime.monday`
  /// и т. д.; для русской локали понедельник.
  factory StatsRange.of(StatsPeriod period, DateTime now, {int weekStart = DateTime.monday, int offset = 0}) {
    final DateTime local = now.toLocal();
    switch (period) {
      case StatsPeriod.week:
        final int back = (local.weekday - weekStart + 7) % 7;
        final int day = local.day - back + 7 * offset;
        return StatsRange(DateTime(local.year, local.month, day), DateTime(local.year, local.month, day + 7));
      case StatsPeriod.month:
        return StatsRange(
          DateTime(local.year, local.month + offset),
          DateTime(local.year, local.month + offset + 1),
        );
      case StatsPeriod.year:
        return StatsRange(DateTime(local.year + offset), DateTime(local.year + offset + 1));
      case StatsPeriod.all:
        return StatsRange.all(local);
    }
  }

  final DateTime start;
  final DateTime end;

  @override
  List<Object?> get props => <Object?>[start, end];
}
