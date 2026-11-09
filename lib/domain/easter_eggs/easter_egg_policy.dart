import 'dart:math';

import 'package:beading/domain/easter_eggs/app_event.dart';
import 'package:beading/domain/easter_eggs/compliment_catalog.dart';
import 'package:beading/domain/easter_eggs/egg_group.dart';
import 'package:beading/domain/easter_eggs/egg_log_entry.dart';
import 'package:beading/domain/settings/special_date.dart';

/// Решает, показывать ли комплимент на событие, и какой ([cross-cutting.md](../../../docs/cross-cutting.md)).
///
/// Чистая: время приходит параметром, случайность — только из [Random] конструктора.
///
/// Три триггера гарантированы (100%) и обходят ограничения редкости: «готово», особая дата и секрет.
/// Остальные (запуск 3%, каждый 100-й ряд 30%, долгая сессия 50%) показываются, только если:
/// прошло 2 минуты после запуска, в этой сессии ещё ничего не показывали и последний показ (любой группы, кроме
/// секрета) был не меньше 3 дней назад.
class EasterEggPolicy {
  EasterEggPolicy({required Random random}) : _random = random;

  /// Порог долгой сессии: событие `LongSession` приходит, когда она перешла его.
  static const Duration longSession = Duration(minutes: 90);

  static const Duration quietAfterStart = Duration(minutes: 2);
  static const Duration minInterval = Duration(days: 3);
  static const int rowsMilestone = 100;
  static const double appStartChance = 0.03;
  static const double rowsChance = 0.3;
  static const double longSessionChance = 0.5;

  final Random _random;

  /// Комплимент для показа или `null` — промолчать.
  Compliment? decide({
    required AppEvent event,
    required DateTime now,
    required DateTime sessionStart,
    required bool shownThisSession,
    required List<EggLogEntry> history,
    required List<SpecialDate> specialDates,
    required ComplimentCatalog catalog,
  }) {
    Compliment? pick(EggGroup group) => _pick(catalog.of(group), history.where((e) => e.group == group));

    Compliment? chance(EggGroup group, double probability) {
      final bool quiet = now.difference(sessionStart) < quietAfterStart;
      if (quiet || shownThisSession || _shownRecently(history, now)) {
        return null;
      }
      return _random.nextDouble() < probability ? pick(group) : null;
    }

    return switch (event) {
      SecretTapped() => pick(EggGroup.secret),
      ProjectCompleted() => pick(EggGroup.completed),
      AppStarted() =>
        _isSpecialDay(specialDates, now) && !_shownToday(history, now)
            ? pick(EggGroup.specialDate)
            : chance(EggGroup.appStart, appStartChance),
      RowsCompleted(:final int total) =>
        total > 0 && total % rowsMilestone == 0 ? chance(EggGroup.rows, rowsChance) : null,
      LongSession() => chance(EggGroup.longSession, longSessionChance),
    };
  }

  bool _shownRecently(List<EggLogEntry> history, DateTime now) =>
      history.any((e) => e.group != EggGroup.secret && now.difference(e.shownAt) < minInterval);

  bool _isSpecialDay(List<SpecialDate> dates, DateTime now) =>
      dates.any((d) => d.month == now.month && d.day == now.day);

  bool _shownToday(List<EggLogEntry> history, DateTime now) => history.any(
    (e) =>
        e.group == EggGroup.specialDate &&
        e.shownAt.year == now.year &&
        e.shownAt.month == now.month &&
        e.shownAt.day == now.day,
  );

  /// Случайный из ещё не показанных в текущем цикле. Цикл заканчивается, когда показаны все тексты группы.
  Compliment? _pick(List<Compliment> texts, Iterable<EggLogEntry> groupLog) {
    if (texts.isEmpty) {
      return null;
    }
    final Set<String> known = <String>{for (final Compliment c in texts) c.id};
    final List<EggLogEntry> chronological = groupLog.where((e) => known.contains(e.eggId)).toList()
      ..sort((a, b) => a.shownAt.compareTo(b.shownAt));
    final Set<String> cycle = <String>{};
    for (final EggLogEntry entry in chronological) {
      cycle.add(entry.eggId);
      if (cycle.length == known.length) {
        cycle.clear();
      }
    }
    final List<Compliment> candidates = texts.where((c) => !cycle.contains(c.id)).toList();
    return candidates[_random.nextInt(candidates.length)];
  }
}
