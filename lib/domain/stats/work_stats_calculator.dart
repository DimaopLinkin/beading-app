import 'package:beading/domain/stats/stats_range.dart';
import 'package:beading/domain/stats/work_stats.dart';
import 'package:beading/domain/weaving/work_session.dart';

/// Считает статистику времени из сессий. Чистая функция: время приходит параметрами.
///
/// - Конец сессии обрезается по «сейчас» (часы другого устройства могли уйти вперёд), длина — по [maxSession]
///   (сессию, которую забыли закрыть, не считаем сутками).
/// - Пересечения (два устройства работали одновременно, два проекта подряд без паузы) объединяются: время не
///   считается дважды. Поэтому сумма по проектам ([byProject]) может быть больше общего итога.
/// - Сессия через полночь делится по местным дням.
class WorkStatsCalculator {
  const WorkStatsCalculator({this.maxSession = const Duration(hours: 12)});

  final Duration maxSession;

  WorkStats compute(List<WorkSession> sessions, StatsRange range, DateTime now) {
    final List<_Span> own = _spans(sessions, now);
    final List<_Span> merged = _merge(_clip(own, range));
    final Map<DateTime, Duration> perDay = <DateTime, Duration>{};
    for (final _Span span in merged) {
      _splitByDay(span, perDay);
    }
    final Duration total = perDay.values.fold(Duration.zero, (a, b) => a + b);
    final int days = perDay.length;
    Duration longest = Duration.zero;
    for (final _Span span in _clip(own, range)) {
      if (span.length > longest) {
        longest = span.length;
      }
    }
    return WorkStats(
      total: total,
      daysWithWork: days,
      averagePerWorkDay: days == 0 ? Duration.zero : Duration(microseconds: total.inMicroseconds ~/ days),
      longestSession: longest,
      perDay: perDay,
    );
  }

  /// Время по проектам за период.
  Map<String, Duration> byProject(List<WorkSession> sessions, StatsRange range, DateTime now) {
    final Map<String, List<WorkSession>> groups = <String, List<WorkSession>>{};
    for (final WorkSession s in sessions) {
      groups.putIfAbsent(s.projectId, () => <WorkSession>[]).add(s);
    }
    return <String, Duration>{
      for (final MapEntry<String, List<WorkSession>> e in groups.entries)
        e.key: _merge(_clip(_spans(e.value, now), range)).fold(Duration.zero, (a, s) => a + s.length),
    };
  }

  List<_Span> _spans(List<WorkSession> sessions, DateTime now) {
    final DateTime cap = now.toUtc();
    final List<_Span> result = <_Span>[];
    for (final WorkSession s in sessions) {
      final DateTime? ended = s.endedAt;
      if (ended == null) {
        continue;
      }
      final DateTime start = s.startedAt.toUtc();
      DateTime end = ended.toUtc();
      if (end.isAfter(cap)) {
        end = cap;
      }
      final DateTime limit = start.add(maxSession);
      if (end.isAfter(limit)) {
        end = limit;
      }
      if (end.isAfter(start)) {
        result.add(_Span(start, end));
      }
    }
    return result;
  }

  List<_Span> _clip(List<_Span> spans, StatsRange range) {
    final DateTime from = range.start.toUtc();
    final DateTime to = range.end.toUtc();
    final List<_Span> result = <_Span>[];
    for (final _Span s in spans) {
      final DateTime start = s.start.isBefore(from) ? from : s.start;
      final DateTime end = s.end.isAfter(to) ? to : s.end;
      if (end.isAfter(start)) {
        result.add(_Span(start, end));
      }
    }
    return result;
  }

  List<_Span> _merge(List<_Span> spans) {
    final List<_Span> sorted = <_Span>[...spans]..sort((a, b) => a.start.compareTo(b.start));
    final List<_Span> result = <_Span>[];
    for (final _Span s in sorted) {
      if (result.isNotEmpty && !s.start.isAfter(result.last.end)) {
        final _Span last = result.removeLast();
        result.add(_Span(last.start, s.end.isAfter(last.end) ? s.end : last.end));
      } else {
        result.add(s);
      }
    }
    return result;
  }

  void _splitByDay(_Span span, Map<DateTime, Duration> perDay) {
    DateTime cursor = span.start.toLocal();
    final DateTime end = span.end.toLocal();
    while (cursor.isBefore(end)) {
      final DateTime day = DateTime(cursor.year, cursor.month, cursor.day);
      final DateTime next = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final DateTime stop = next.isBefore(end) ? next : end;
      perDay[day] = (perDay[day] ?? Duration.zero) + stop.difference(cursor);
      cursor = stop;
    }
  }
}

class _Span {
  const _Span(this.start, this.end);

  final DateTime start;
  final DateTime end;

  Duration get length => end.difference(start);
}
