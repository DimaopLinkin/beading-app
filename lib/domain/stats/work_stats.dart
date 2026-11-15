import 'package:equatable/equatable.dart';

/// Статистика времени за период. Дни — местные, ключ карты — полночь дня.
final class WorkStats extends Equatable {
  const WorkStats({
    required this.total,
    required this.daysWithWork,
    required this.averagePerWorkDay,
    required this.longestSession,
    required this.perDay,
  });

  final Duration total;
  final int daysWithWork;
  final Duration averagePerWorkDay;
  final Duration longestSession;
  final Map<DateTime, Duration> perDay;

  @override
  List<Object?> get props => <Object?>[total, daysWithWork, averagePerWorkDay, longestSession, perDay];
}
