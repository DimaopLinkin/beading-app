import 'dart:math';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/easter_eggs/app_event.dart';
import 'package:beading/domain/easter_eggs/app_events.dart';
import 'package:beading/domain/easter_eggs/compliment_catalog.dart';
import 'package:beading/domain/easter_eggs/compliment_source.dart';
import 'package:beading/domain/easter_eggs/easter_egg_policy.dart';
import 'package:beading/domain/easter_eggs/easter_egg_service.dart';
import 'package:beading/domain/easter_eggs/egg_group.dart';
import 'package:beading/domain/easter_eggs/egg_log_entry.dart';
import 'package:beading/domain/easter_eggs/shown_compliment.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/special_date.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_easter_egg_log.dart';
import '../../support/fake_settings_repository.dart';

class _FakeSource implements ComplimentSource {
  _FakeSource(this.result);

  Result<ComplimentCatalog> result;
  int loads = 0;

  @override
  Future<Result<ComplimentCatalog>> load() async {
    loads++;
    return result;
  }
}

class _AlwaysLucky implements Random {
  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => true;
}

ComplimentCatalog _catalog() => ComplimentCatalog(<EggGroup, List<Compliment>>{
  for (final EggGroup group in EggGroup.values)
    group: <Compliment>[
      Compliment(group: group, text: '{name}: ${group.name} 0'),
      Compliment(group: group, text: '{name}: ${group.name} 1'),
    ],
});

void main() {
  late FakeClock clock;
  late FakeEasterEggLog log;
  late FakeSettingsRepository settings;
  late _FakeSource source;
  late AppEvents events;
  late EasterEggService service;
  late List<ShownCompliment> shown;

  setUp(() {
    clock = FakeClock(DateTime(2026, 11, 9, 12));
    log = FakeEasterEggLog();
    settings = FakeSettingsRepository();
    source = _FakeSource(Success<ComplimentCatalog>(_catalog()));
    events = AppEvents();
    service = EasterEggService(
      events: events,
      policy: EasterEggPolicy(random: _AlwaysLucky()),
      log: log,
      source: source,
      settings: settings,
      clock: clock,
    );
    shown = <ShownCompliment>[];
    service.shown.listen(shown.add);
  });

  tearDown(() async {
    await service.dispose();
    await events.close();
  });

  Future<void> emit(AppEvent event) async {
    events.add(event);
    await pumpEventQueue();
  }

  test('до start события игнорируются', () async {
    await emit(const SecretTapped());

    expect(shown, isEmpty);
  });

  test('показывает комплимент с именем из настроек и пишет в журнал', () async {
    service.start();
    settings.values[SettingKeys.userName.name] = 'Маша';

    await emit(const ProjectCompleted());

    expect(shown, hasLength(1));
    expect(shown.single.text, startsWith('Маша: completed'));
    expect(log.entries, hasLength(1));
    expect(log.entries.single.group, EggGroup.completed);
    expect(log.entries.single.shownAt, clock.now());
    expect(log.entries.single.eggId, startsWith('completed:'));
  });

  test('имя по умолчанию — Настя', () async {
    service.start();

    await emit(const SecretTapped());

    expect(shown.single.text, startsWith('Настя: secret'));
  });

  test('первые 2 минуты случайные молчат, потом говорят; не больше одного за сессию', () async {
    service.start();

    await emit(const LongSession());
    expect(shown, isEmpty, reason: 'тишина первые 2 минуты');

    clock.advance(const Duration(minutes: 3));
    await emit(const LongSession());
    expect(shown, hasLength(1));

    await emit(const LongSession());
    expect(shown, hasLength(1), reason: 'один за сессию');
  });

  test('«готово» показывается и после случайного в той же сессии', () async {
    service.start();
    clock.advance(const Duration(minutes: 3));

    await emit(const LongSession());
    await emit(const ProjectCompleted());

    expect(shown, hasLength(2));
  });

  test('история из журнала учитывается: недавний показ блокирует случайный', () async {
    service.start();
    clock.advance(const Duration(minutes: 3));
    await emit(const ProjectCompleted());
    shown.clear();

    // Новая сессия: тот же журнал.
    final EasterEggService next = EasterEggService(
      events: events,
      policy: EasterEggPolicy(random: _AlwaysLucky()),
      log: log,
      source: source,
      settings: settings,
      clock: clock,
    )..start();
    addTearDown(next.dispose);
    final List<ShownCompliment> nextShown = <ShownCompliment>[];
    next.shown.listen(nextShown.add);
    clock.advance(const Duration(minutes: 3));
    await emit(const LongSession());

    expect(nextShown, isEmpty);
  });

  test('особая дата из настроек показывается при запуске', () async {
    settings.values[SettingKeys.specialDates.name] = <SpecialDate>[const SpecialDate(label: 'ДР', month: 11, day: 9)];
    service.start();

    await emit(const AppStarted());

    expect(shown.single.text, contains('specialDate'));
  });

  test('события обрабатываются по очереди: два «готово» подряд дают два разных текста', () async {
    service.start();

    events
      ..add(const ProjectCompleted())
      ..add(const ProjectCompleted());
    await pumpEventQueue();

    expect(shown.map((s) => s.text).toSet(), hasLength(2));
  });

  test('ошибка загрузки текстов — тишина, сервис жив и пробует снова', () async {
    source.result = const Err<ComplimentCatalog>(ValidationFailure('битый файл'));
    service.start();

    await emit(const SecretTapped());
    expect(shown, isEmpty);

    source.result = Success<ComplimentCatalog>(_catalog());
    await emit(const SecretTapped());
    expect(shown, hasLength(1));
  });

  test('ошибка чтения журнала — тишина', () async {
    log.failing = true;
    service.start();

    await emit(const SecretTapped());

    expect(shown, isEmpty);
  });

  test('сбой записи в журнал не мешает показать комплимент, но не ломает сервис', () async {
    final EasterEggService s = EasterEggService(
      events: events,
      policy: EasterEggPolicy(random: _AlwaysLucky()),
      log: _WriteFailingLog(),
      source: source,
      settings: settings,
      clock: clock,
    )..start();
    addTearDown(s.dispose);
    final List<ShownCompliment> out = <ShownCompliment>[];
    s.shown.listen(out.add);

    await emit(const SecretTapped());

    expect(out, hasLength(1));
  });

  test('каталог загружается один раз', () async {
    service.start();

    await emit(const SecretTapped());
    await emit(const SecretTapped());

    expect(source.loads, 1);
  });

  test('после dispose события не обрабатываются, повторный dispose безопасен', () async {
    service.start();
    await service.dispose();

    await emit(const SecretTapped());
    await service.dispose();

    expect(shown, isEmpty);
  });
}

class _WriteFailingLog extends FakeEasterEggLog {
  @override
  Future<Result<void>> add(EggLogEntry entry) async => const Err<void>(StorageFailure('boom'));
}
