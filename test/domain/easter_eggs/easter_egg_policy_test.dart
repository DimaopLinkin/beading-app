import 'dart:math';

import 'package:beading/domain/easter_eggs/compliment_catalog.dart';
import 'package:beading/domain/easter_eggs/easter_egg_policy.dart';
import 'package:beading/domain/easter_eggs/egg_group.dart';
import 'package:beading/domain/easter_eggs/egg_log_entry.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/settings/special_date.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Random` с заранее заданными значениями `nextDouble`; `nextInt` берёт `next % max`.
class _ScriptedRandom implements Random {
  _ScriptedRandom(this._doubles);

  final List<double> _doubles;
  int _index = 0;

  @override
  double nextDouble() => _doubles[_index++ % _doubles.length];

  @override
  int nextInt(int max) => (nextDouble() * max).floor();

  @override
  bool nextBool() => nextDouble() < 0.5;
}

final DateTime _start = DateTime(2026, 11, 9, 12);

ComplimentCatalog _catalog({int perGroup = 3}) => ComplimentCatalog(<EggGroup, List<Compliment>>{
  for (final EggGroup group in EggGroup.values)
    group: <Compliment>[for (int i = 0; i < perGroup; i++) Compliment(group: group, text: '${group.name} $i')],
});

/// Решение политики в сценарии «сессия идёт [sinceStart], в истории [history]».
Compliment? _decide(
  EasterEggPolicy policy,
  AppEvent event, {
  Duration sinceStart = const Duration(minutes: 10),
  bool shownThisSession = false,
  List<EggLogEntry> history = const <EggLogEntry>[],
  List<SpecialDate> specialDates = const <SpecialDate>[],
  ComplimentCatalog? catalog,
}) => policy.decide(
  event: event,
  now: _start.add(sinceStart),
  sessionStart: _start,
  shownThisSession: shownThisSession,
  history: history,
  specialDates: specialDates,
  catalog: catalog ?? _catalog(),
);

EggLogEntry _entry(EggGroup group, {String? text, required DateTime at, int index = 0}) =>
    EggLogEntry(group: group, eggId: '${group.name}:${text ?? '${group.name} $index'}', shownAt: at);

void main() {
  // Бросок «не повезло» проваливает любой шанс (3–50%); «повезло» (0.0) выигрывает любой.
  _ScriptedRandom unlucky() => _ScriptedRandom(<double>[0.999]);

  EasterEggPolicy luckyPolicy() => EasterEggPolicy(random: _ScriptedRandom(<double>[0.0]));

  group('шансы по триггерам', () {
    test('«готово» — всегда, даже при неудачном броске', () {
      expect(_decide(EasterEggPolicy(random: unlucky()), const ProjectCompleted('p1')), isNotNull);
    });

    test('секрет — всегда', () {
      final Compliment? shown = _decide(EasterEggPolicy(random: unlucky()), const SecretTapped());

      expect(shown!.group, EggGroup.secret);
    });

    test('запуск: 3% — 0.029 показывает, 0.03 нет', () {
      expect(_decide(EasterEggPolicy(random: _ScriptedRandom(<double>[0.029])), const AppStarted()), isNotNull);
      expect(_decide(EasterEggPolicy(random: _ScriptedRandom(<double>[0.03])), const AppStarted()), isNull);
    });

    test('ряды: 30% на каждом сотом ряду', () {
      expect(_decide(EasterEggPolicy(random: _ScriptedRandom(<double>[0.29])), const RowsCompleted(100)), isNotNull);
      expect(_decide(EasterEggPolicy(random: _ScriptedRandom(<double>[0.3])), const RowsCompleted(100)), isNull);
    });

    test('ряды: не сотый ряд — тишина, включая 0, 99, 101 и 150', () {
      for (final int total in <int>[0, 1, 99, 101, 150]) {
        expect(_decide(luckyPolicy(), RowsCompleted(total)), isNull, reason: '$total');
      }
      expect(_decide(luckyPolicy(), const RowsCompleted(200)), isNotNull);
    });

    test('долгая сессия: 50%', () {
      expect(_decide(EasterEggPolicy(random: _ScriptedRandom(<double>[0.49])), const LongSession()), isNotNull);
      expect(_decide(EasterEggPolicy(random: _ScriptedRandom(<double>[0.5])), const LongSession()), isNull);
    });

    test('группа комплимента совпадает с триггером', () {
      expect(_decide(luckyPolicy(), const ProjectCompleted('p1'))!.group, EggGroup.completed);
      expect(_decide(luckyPolicy(), const RowsCompleted(100))!.group, EggGroup.rows);
      expect(_decide(luckyPolicy(), const StitchBlockCompleted(projectId: 'p1', total: 3))!.group, EggGroup.rows);
      expect(_decide(luckyPolicy(), const StitchColorCompleted('p1'))!.group, EggGroup.rows);
      expect(_decide(luckyPolicy(), const AppStarted())!.group, EggGroup.appStart);
      expect(_decide(luckyPolicy(), const LongSession())!.group, EggGroup.longSession);
    });

    test('с сидом частота запуска близка к 3%', () {
      final EasterEggPolicy policy = EasterEggPolicy(random: Random(42));
      int shown = 0;
      for (int i = 0; i < 10000; i++) {
        if (_decide(policy, const AppStarted()) != null) {
          shown++;
        }
      }

      expect(shown, inInclusiveRange(200, 400));
    });
  });

  group('ограничения редкости', () {
    final DateTime now = _start.add(const Duration(minutes: 10));

    test('первые 2 минуты — тишина; ровно 2 минуты уже можно', () {
      expect(_decide(luckyPolicy(), const AppStarted(), sinceStart: const Duration(minutes: 1, seconds: 59)), isNull);
      expect(_decide(luckyPolicy(), const AppStarted(), sinceStart: const Duration(minutes: 2)), isNotNull);
    });

    test('не больше одного за сессию', () {
      expect(_decide(luckyPolicy(), const LongSession(), shownThisSession: true), isNull);
    });

    test('не чаще одного раза в 3 дня: 2 дня 23 часа назад — нельзя, ровно 3 дня — можно', () {
      final List<EggLogEntry> recent = <EggLogEntry>[
        _entry(EggGroup.appStart, at: now.subtract(const Duration(days: 2, hours: 23))),
      ];
      final List<EggLogEntry> old = <EggLogEntry>[_entry(EggGroup.appStart, at: now.subtract(const Duration(days: 3)))];

      expect(_decide(luckyPolicy(), const LongSession(), history: recent), isNull);
      expect(_decide(luckyPolicy(), const LongSession(), history: old), isNotNull);
    });

    test('интервал в 3 дня считается по любой группе, кроме секрета', () {
      final List<EggLogEntry> afterCompleted = <EggLogEntry>[
        _entry(EggGroup.completed, at: now.subtract(const Duration(hours: 5))),
      ];
      final List<EggLogEntry> afterSecret = <EggLogEntry>[
        _entry(EggGroup.secret, at: now.subtract(const Duration(hours: 5))),
      ];

      expect(_decide(luckyPolicy(), const LongSession(), history: afterCompleted), isNull);
      expect(_decide(luckyPolicy(), const LongSession(), history: afterSecret), isNotNull);
    });

    test('«готово», особая дата и секрет игнорируют интервал, сессию и тишину первых минут', () {
      final List<EggLogEntry> history = <EggLogEntry>[
        _entry(EggGroup.rows, at: now.subtract(const Duration(hours: 1))),
      ];
      const List<SpecialDate> today = <SpecialDate>[SpecialDate(label: 'ДР', month: 11, day: 9)];

      expect(
        _decide(
          luckyPolicy(),
          const ProjectCompleted('p1'),
          history: history,
          shownThisSession: true,
          sinceStart: Duration.zero,
        ),
        isNotNull,
      );
      expect(
        _decide(
          luckyPolicy(),
          const SecretTapped(),
          history: history,
          shownThisSession: true,
          sinceStart: Duration.zero,
        ),
        isNotNull,
      );
      expect(
        _decide(
          luckyPolicy(),
          const AppStarted(),
          history: history,
          shownThisSession: true,
          sinceStart: Duration.zero,
          specialDates: today,
        )!.group,
        EggGroup.specialDate,
      );
    });
  });

  group('особые даты', () {
    const List<SpecialDate> today = <SpecialDate>[SpecialDate(label: 'ДР', month: 11, day: 9)];

    test('в особую дату при запуске — всегда, даже при неудачном броске', () {
      final Compliment? shown = _decide(EasterEggPolicy(random: unlucky()), const AppStarted(), specialDates: today);

      expect(shown!.group, EggGroup.specialDate);
    });

    test('другая дата — обычная логика запуска', () {
      const List<SpecialDate> other = <SpecialDate>[SpecialDate(label: '8 марта', month: 3, day: 8)];

      expect(_decide(EasterEggPolicy(random: unlucky()), const AppStarted(), specialDates: other), isNull);
    });

    test('раз в день: повторный запуск в тот же день не показывает', () {
      final List<EggLogEntry> history = <EggLogEntry>[
        _entry(EggGroup.specialDate, at: DateTime(2026, 11, 9, 8)),
      ];

      expect(_decide(unluckyPolicy(), const AppStarted(), specialDates: today, history: history), isNull);
    });

    test('вчерашний показ не мешает сегодняшнему', () {
      final List<EggLogEntry> history = <EggLogEntry>[
        _entry(EggGroup.specialDate, at: DateTime(2026, 11, 8, 23, 59)),
      ];

      expect(
        _decide(unluckyPolicy(), const AppStarted(), specialDates: today, history: history)!.group,
        EggGroup.specialDate,
      );
    });

    test('особая дата проверяется только на запуске приложения', () {
      expect(_decide(unluckyPolicy(), const RowsCompleted(100), specialDates: today), isNull);
    });

    test('невозможная дата (31 февраля) никогда не совпадает', () {
      const List<SpecialDate> impossible = <SpecialDate>[SpecialDate(label: 'ошибка', month: 2, day: 31)];

      expect(_decide(unluckyPolicy(), const AppStarted(), specialDates: impossible), isNull);
    });
  });

  group('неповторяемость', () {
    test('пока не показаны все тексты группы, показанный не повторяется', () {
      final List<EggLogEntry> history = <EggLogEntry>[];
      final EasterEggPolicy policy = EasterEggPolicy(random: Random(7));
      final Set<String> seen = <String>{};

      for (int i = 0; i < 3; i++) {
        final Compliment shown = _decide(policy, const ProjectCompleted('p1'), history: history)!;
        seen.add(shown.id);
        history.add(
          EggLogEntry(
            group: shown.group,
            eggId: shown.id,
            shownAt: _start.add(Duration(days: i)),
          ),
        );
      }

      expect(seen, hasLength(3), reason: 'три показа — три разных текста из трёх');
    });

    test('когда все показаны, цикл начинается заново, но не раньше исчерпания', () {
      final List<EggLogEntry> history = <EggLogEntry>[];
      final EasterEggPolicy policy = EasterEggPolicy(random: Random(11));
      final List<String> order = <String>[];

      for (int i = 0; i < 6; i++) {
        final Compliment shown = _decide(policy, const ProjectCompleted('p1'), history: history)!;
        order.add(shown.id);
        history.add(
          EggLogEntry(
            group: shown.group,
            eggId: shown.id,
            shownAt: _start.add(Duration(days: i)),
          ),
        );
      }

      expect(order.sublist(0, 3).toSet(), hasLength(3));
      expect(order.sublist(3).toSet(), hasLength(3), reason: 'второй цикл тоже без повторов внутри');
    });

    test('история одной группы не влияет на другую', () {
      final List<EggLogEntry> history = <EggLogEntry>[
        for (int i = 0; i < 2; i++)
          _entry(
            EggGroup.rows,
            at: _start.add(Duration(days: i)),
            index: i,
          ),
      ];

      final Set<String> seen = <String>{};
      final EasterEggPolicy policy = EasterEggPolicy(random: Random(3));
      for (int i = 0; i < 40; i++) {
        seen.add(_decide(policy, const ProjectCompleted('p1'), history: history)!.id);
      }

      expect(seen, hasLength(3), reason: 'в completed доступны все три текста');
    });

    test('если в истории остался текст, которого уже нет в файле, он игнорируется', () {
      final List<EggLogEntry> history = <EggLogEntry>[
        EggLogEntry(group: EggGroup.completed, eggId: 'completed:удалённый текст', shownAt: _start),
      ];

      expect(_decide(luckyPolicy(), const ProjectCompleted('p1'), history: history), isNotNull);
    });

    test('выбор среди оставшихся определяется Random', () {
      final List<EggLogEntry> history = <EggLogEntry>[_entry(EggGroup.completed, at: _start)];

      final Compliment? first = _decide(
        EasterEggPolicy(random: _ScriptedRandom(<double>[0.0])),
        const ProjectCompleted('p1'),
        history: history,
      );
      final Compliment? last = _decide(
        EasterEggPolicy(random: _ScriptedRandom(<double>[0.99])),
        const ProjectCompleted('p1'),
        history: history,
      );

      expect(first!.text, 'completed 1');
      expect(last!.text, 'completed 2');
    });
  });

  test('пустая группа каталога — тишина, а не падение', () {
    const ComplimentCatalog empty = ComplimentCatalog(<EggGroup, List<Compliment>>{});

    expect(_decide(luckyPolicy(), const ProjectCompleted('p1'), catalog: empty), isNull);
  });

  test('порог долгой сессии — 90 минут', () {
    expect(EasterEggPolicy.longSession, const Duration(minutes: 90));
  });
}

EasterEggPolicy unluckyPolicy() => EasterEggPolicy(random: _ScriptedRandom(<double>[0.999]));
