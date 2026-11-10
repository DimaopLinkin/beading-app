import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/weaving/rows_counter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_settings_repository.dart';

void main() {
  late FakeSettingsRepository settings;
  late BroadcastAppEvents events;
  late List<AppEvent> published;
  late RowsCounter counter;

  setUp(() {
    settings = FakeSettingsRepository();
    events = BroadcastAppEvents();
    published = <AppEvent>[];
    events.stream.listen(published.add);
    counter = RowsCounter(settings: settings, events: events);
  });

  tearDown(() => events.dispose());

  test('каждый отмеченный ряд увеличивает итог и шлёт RowsCompleted', () async {
    expect((await counter.completed()).valueOrNull, 1);
    expect((await counter.completed()).valueOrNull, 2);
    expect(published, <Matcher>[
      isA<RowsCompleted>().having((e) => e.total, 'total', 1),
      isA<RowsCompleted>().having((e) => e.total, 'total', 2),
    ]);
    expect(settings.values[SettingKeys.rowsCompleted.name], 2);
  });

  test('снятая отметка уменьшает итог, но не ниже нуля, и события не шлёт', () async {
    await counter.completed();
    published.clear();
    expect((await counter.undone()).valueOrNull, 0);
    expect((await counter.undone()).valueOrNull, 0);
    expect(published, isEmpty);
  });

  test('счётчик локальный: не уходит в синхронизацию', () {
    expect(SettingKeys.rowsCompleted.isLocal, isTrue);
  });

  test('сбой записи: ошибка, события нет', () async {
    settings.failWrites = true;
    expect((await counter.completed()).isFailure, isTrue);
    expect(published, isEmpty);
  });
}
