import 'package:beading/data/settings/in_memory_keep_screen_awake_setting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('по умолчанию включено', () async {
    expect(await InMemoryKeepScreenAwakeSetting().read(), isTrue);
  });

  test('запись меняет значение и уведомляет подписчиков', () async {
    final InMemoryKeepScreenAwakeSetting setting = InMemoryKeepScreenAwakeSetting();
    final Future<List<bool>> seen = setting.watch().take(2).toList();

    await setting.write(value: false);
    await setting.write(value: true);

    expect(await seen, <bool>[false, true]);
    expect(await setting.read(), isTrue);
  });
}
