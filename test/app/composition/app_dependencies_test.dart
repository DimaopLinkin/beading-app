import 'package:beading/app/composition/app_dependencies.dart';
import 'package:beading/app/composition/core_module.dart';
import 'package:beading/core/clock.dart';
import 'package:beading/core/id_generator.dart';
import 'package:beading/data/easter_eggs/asset_compliment_source.dart';
import 'package:beading/data/easter_eggs/drift_easter_egg_log.dart';
import 'package:beading/data/settings/drift_device_id_provider.dart';
import 'package:beading/data/settings/drift_settings_repository.dart';
import 'package:beading/data/settings/package_info_app_info_provider.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/settings/app_events_secret_tap_handler.dart';
import 'package:beading/presentation/easter_eggs/compliment_banner_cubit.dart';
import 'package:beading/presentation/settings/settings_cubit.dart';
import 'package:beading/presentation/theme/theme_mode_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/in_memory_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoreModule', () {
    test('собирает ядро из базы без глобального состояния', () {
      final CoreModule core = CoreModule(database: createInMemoryDatabase());
      addTearDown(core.dispose);

      expect(core.clock, isA<SystemClock>());
      expect(core.ids, isA<UuidV7IdGenerator>());
      expect(core.deviceIds, isA<DriftDeviceIdProvider>());
      expect(core.settings, isA<DriftSettingsRepository>());
      expect(core.events, isA<BroadcastAppEvents>());
    });

    test('объекты ядра создаются один раз', () {
      final CoreModule core = CoreModule(database: createInMemoryDatabase());
      addTearDown(core.dispose);

      expect(core.settings, same(core.settings));
      expect(core.events, same(core.events));
    });

    test('принимает подмену часов', () {
      final Clock fake = FakeClock(DateTime.utc(2026, 11, 12));
      final CoreModule core = CoreModule(database: createInMemoryDatabase(), clock: fake);
      addTearDown(core.dispose);

      expect(core.clock, same(fake));
    });
  });

  group('AppDependencies', () {
    test('держит ядро', () {
      final CoreModule core = CoreModule(database: createInMemoryDatabase());
      final AppDependencies dependencies = AppDependencies(core: core);
      addTearDown(dependencies.dispose);

      expect(dependencies.core, same(core));
    });

    test('dispose можно вызвать повторно', () async {
      final AppDependencies dependencies = AppDependencies(
        core: CoreModule(database: createInMemoryDatabase()),
      );

      await dependencies.dispose();
      await dependencies.dispose();
    });
  });

  group('EasterEggsModule', () {
    test('собирает пасхалки и создаёт сервис один раз', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      expect(dependencies.easterEggs.log, isA<DriftEasterEggLog>());
      expect(dependencies.easterEggs.complimentSource, isA<AssetComplimentSource>());
      expect(dependencies.easterEggs.service, same(dependencies.easterEggs.service));
      expect(dependencies.easterEggs.longSession, same(dependencies.easterEggs.longSession));
    });

    test('баннер — новый объект на каждый вызов', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      final ComplimentBannerCubit first = dependencies.easterEggs.complimentBannerCubit();
      final ComplimentBannerCubit second = dependencies.easterEggs.complimentBannerCubit();
      addTearDown(first.close);
      addTearDown(second.close);

      expect(first, isNot(same(second)));
    });

    test('dispose закрывает созданные сервисы', () async {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      dependencies.easterEggs
        ..service
        ..longSession;

      await dependencies.dispose();
    });
  });

  group('SettingsModule', () {
    test('отдаёт «О приложении» и обработчик секретных нажатий', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      expect(dependencies.settings.appInfo, isA<PackageInfoAppInfoProvider>());
      expect(dependencies.settings.secretTapHandler, isA<AppEventsSecretTapHandler>());
    });

    test('кубиты темы и настроек создаются заново на каждый вызов', () {
      final AppDependencies dependencies = AppDependencies(core: CoreModule(database: createInMemoryDatabase()));
      addTearDown(dependencies.dispose);

      final ThemeModeCubit theme = dependencies.settings.themeModeCubit();
      final SettingsCubit settings = dependencies.settings.settingsCubit();
      addTearDown(theme.close);
      addTearDown(settings.close);

      expect(theme, isNot(same(dependencies.settings.themeModeCubit())));
      expect(settings, isNot(same(dependencies.settings.settingsCubit())));
    });
  });
}
