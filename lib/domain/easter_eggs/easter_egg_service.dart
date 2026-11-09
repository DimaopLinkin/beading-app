import 'dart:async';

import 'package:beading/core/clock.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/easter_eggs/app_event.dart';
import 'package:beading/domain/easter_eggs/app_events.dart';
import 'package:beading/domain/easter_eggs/compliment_catalog.dart';
import 'package:beading/domain/easter_eggs/compliment_source.dart';
import 'package:beading/domain/easter_eggs/easter_egg_log.dart';
import 'package:beading/domain/easter_eggs/easter_egg_policy.dart';
import 'package:beading/domain/easter_eggs/egg_log_entry.dart';
import 'package:beading/domain/easter_eggs/shown_compliment.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/domain/settings/special_date.dart';

/// Слушает [AppEvents], спрашивает [EasterEggPolicy] и отдаёт комплимент в поток [shown].
///
/// Пасхалка — необязательная мелочь: любая ошибка (битый файл текстов, сбой базы) означает «промолчать» и никогда
/// не доходит до пользовательницы и не останавливает сервис.
class EasterEggService {
  EasterEggService({
    required AppEvents events,
    required EasterEggPolicy policy,
    required EasterEggLog log,
    required ComplimentSource source,
    required SettingsRepository settings,
    required Clock clock,
  }) : _events = events,
       _policy = policy,
       _log = log,
       _source = source,
       _settings = settings,
       _clock = clock;

  final AppEvents _events;
  final EasterEggPolicy _policy;
  final EasterEggLog _log;
  final ComplimentSource _source;
  final SettingsRepository _settings;
  final Clock _clock;

  final StreamController<ShownCompliment> _shown = StreamController<ShownCompliment>.broadcast();

  StreamSubscription<void>? _subscription;
  DateTime? _sessionStart;
  bool _shownThisSession = false;
  ComplimentCatalog? _catalog;

  /// Комплименты, которые пора показать.
  Stream<ShownCompliment> get shown => _shown.stream;

  /// Начало сессии — момент вызова. Повторный вызов ничего не делает.
  void start() {
    if (_subscription != null) {
      return;
    }
    _sessionStart = _clock.now();
    // asyncMap обрабатывает события строго по очереди: счётчики сессии и журнал не гоняются.
    _subscription = _events.stream.asyncMap(_handle).listen((_) {});
  }

  Future<void> dispose() async {
    final StreamSubscription<void>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    if (!_shown.isClosed) {
      await _shown.close();
    }
  }

  Future<void> _handle(AppEvent event) async {
    try {
      final ComplimentCatalog? catalog = await _loadCatalog();
      final List<EggLogEntry>? history = (await _log.all()).valueOrNull;
      if (catalog == null || history == null) {
        return;
      }
      final String name = (await _settings.read(SettingKeys.userName)).valueOrNull ?? SettingKeys.userName.defaultValue;
      final List<SpecialDate> dates =
          (await _settings.read(SettingKeys.specialDates)).valueOrNull ?? SettingKeys.specialDates.defaultValue;
      final DateTime now = _clock.now();
      final Compliment? compliment = _policy.decide(
        event: event,
        now: now,
        sessionStart: _sessionStart ?? now,
        shownThisSession: _shownThisSession,
        history: history,
        specialDates: dates,
        catalog: catalog,
      );
      if (compliment == null) {
        return;
      }
      _shownThisSession = true;
      // Сначала запись, потом показ: если запись упала, показать всё равно можно, повтор в следующий раз не страшен.
      await _log.add(EggLogEntry(group: compliment.group, eggId: compliment.id, shownAt: now));
      if (!_shown.isClosed) {
        _shown.add(ShownCompliment(compliment.render(name)));
      }
    } on Object {
      // Пасхалка не должна ронять приложение; следующий запуск попробует снова.
      return;
    }
  }

  Future<ComplimentCatalog?> _loadCatalog() async {
    if (_catalog != null) {
      return _catalog;
    }
    return _catalog = (await _source.load()).valueOrNull;
  }
}
