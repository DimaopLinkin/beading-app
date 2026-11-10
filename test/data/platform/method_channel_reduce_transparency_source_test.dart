import 'package:beading/data/platform/method_channel_reduce_transparency_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(MethodChannelReduceTransparencySource.name);
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late MethodChannelReduceTransparencySource source;

  setUp(() => source = MethodChannelReduceTransparencySource());
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await source.dispose();
  });

  test('канал называется app.beading/accessibility', () {
    expect(MethodChannelReduceTransparencySource.name, 'app.beading/accessibility');
  });

  test('current возвращает ответ платформы', () async {
    final List<String> calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });

    expect(await source.current(), isTrue);
    expect(calls, <String>['isReduceTransparencyEnabled']);
  });

  test('null от платформы считается выключенным', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);

    expect(await source.current(), isFalse);
  });

  test('без нативной части current возвращает false', () async {
    expect(await source.current(), isFalse);
  });

  test('ошибка платформы не роняет приложение', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'boom'));

    expect(await source.current(), isFalse);
  });

  test('смена настройки от платформы приходит в поток', () async {
    final Future<List<bool>> received = source.changes.take(2).toList();

    await _sendFromPlatform(channel, 'reduceTransparencyChanged', true);
    await _sendFromPlatform(channel, 'reduceTransparencyChanged', false);

    expect(await received, <bool>[true, false]);
  });

  test('чужие вызовы и не-bool аргументы игнорируются', () async {
    final List<bool> received = <bool>[];
    final sub = source.changes.listen(received.add);

    await _sendFromPlatform(channel, 'somethingElse', true);
    await _sendFromPlatform(channel, 'reduceTransparencyChanged', 'yes');
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(received, isEmpty);
  });
}

Future<void> _sendFromPlatform(MethodChannel channel, String method, Object? arguments) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall(method, arguments)),
    (_) {},
  );
}
