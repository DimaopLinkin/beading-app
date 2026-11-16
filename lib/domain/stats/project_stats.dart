import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/stats/project_pace.dart';
import 'package:beading/domain/stats/project_progress.dart';
import 'package:equatable/equatable.dart';

/// Статистика одного проекта: время, прогресс на сегодня и оценка темпа.
final class ProjectStats extends Equatable {
  const ProjectStats({
    required this.project,
    required this.total,
    required this.sessionCount,
    required this.averageSession,
    required this.recentDays,
    this.firstDay,
    this.lastDay,
    this.progress,
    this.pace,
  });

  final Project project;
  final Duration total;
  final int sessionCount;
  final Duration averageSession;

  /// Местные дни с работой: первый и последний; `null`, пока сессий нет.
  final DateTime? firstDay;
  final DateTime? lastDay;

  /// Дни с работой, новые первыми (до 14 дней).
  final List<MapEntry<DateTime, Duration>> recentDays;

  /// `null` у проектов без счётных клеток (схема из книги, инструкция).
  final ProjectProgress? progress;

  /// `null`, пока оценивать рано или всё уже сделано.
  final ProjectPace? pace;

  /// Календарных дней от первого до последнего дня работы включительно (для «Закончено: 126 ч за 48 дней»).
  int get spanDays {
    final DateTime? first = firstDay;
    final DateTime? last = lastDay;
    if (first == null || last == null) {
      return 0;
    }
    return DateTime.utc(
          last.year,
          last.month,
          last.day,
        ).difference(DateTime.utc(first.year, first.month, first.day)).inDays +
        1;
  }

  @override
  List<Object?> get props => <Object?>[
    project,
    total,
    sessionCount,
    averageSession,
    firstDay,
    lastDay,
    recentDays,
    progress,
    pace,
  ];
}
