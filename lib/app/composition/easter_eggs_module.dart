import 'dart:math';

import 'package:beading/app/composition/core_module.dart';
import 'package:beading/data/easter_eggs/asset_compliment_source.dart';
import 'package:beading/data/easter_eggs/drift_easter_egg_log.dart';
import 'package:beading/domain/easter_eggs/compliment_source.dart';
import 'package:beading/domain/easter_eggs/easter_egg_log.dart';
import 'package:beading/domain/easter_eggs/easter_egg_policy.dart';
import 'package:beading/domain/easter_eggs/easter_egg_service.dart';
import 'package:beading/domain/easter_eggs/long_session_watcher.dart';
import 'package:beading/presentation/easter_eggs/compliment_banner_cubit.dart';

/// Пасхалки-комплименты (ADR-0007): журнал, источник фраз, сервис и наблюдатель за долгой работой.
final class EasterEggsModule {
  EasterEggsModule({required CoreModule core}) : _core = core;

  final CoreModule _core;

  late final EasterEggLog log = DriftEasterEggLog(_core.database.easterEggLogDao);

  late final ComplimentSource complimentSource = AssetComplimentSource();

  EasterEggService? _service;
  LongSessionWatcher? _longSession;

  /// На всё приложение, создаётся при первом обращении.
  EasterEggService get service => _service ??= EasterEggService(
    events: _core.events,
    // Композиционный корень: единственное место, где создаётся источник случайности пасхалок.
    policy: EasterEggPolicy(random: Random()),
    log: log,
    source: complimentSource,
    settings: _core.settings,
    clock: _core.clock,
  );

  /// На всё приложение.
  LongSessionWatcher get longSession => _longSession ??= LongSessionWatcher(events: _core.events, clock: _core.clock);

  /// Новый баннер на каждый вызов; владелец закрывает его сам.
  ComplimentBannerCubit complimentBannerCubit() => ComplimentBannerCubit(service.shown);

  /// Закрывает только то, что было создано.
  Future<void> dispose() async {
    _longSession?.dispose();
    await _service?.dispose();
  }
}
