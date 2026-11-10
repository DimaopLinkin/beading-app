import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/sharing/platform_incoming_biser_files.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(PlatformIncomingBiserFiles.channelName);
  final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late StreamController<Uri> links;
  final List<String> readPaths = <String>[];
  final List<String> platformCalls = <String>[];

  PlatformIncomingBiserFiles source({bool failRead = false}) => PlatformIncomingBiserFiles(
    links: links.stream,
    read: (path) async {
      readPaths.add(path);
      if (failRead) throw StateError('нет файла');
      return Uint8List.fromList(<int>[1, 2, 3]);
    },
  );

  Future<void> sendFromPlatform(List<String> paths) => messenger.handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall(PlatformIncomingBiserFiles.openMethod, paths)),
    (_) {},
  );

  setUp(() {
    links = StreamController<Uri>();
    readPaths.clear();
    platformCalls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      platformCalls.add(call.method);
      return null;
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await links.close();
  });

  test('при подписке сообщает платформе «ready»', () async {
    final StreamSubscription<Result<BiserFile>> sub = source().files.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    expect(platformCalls, <String>[PlatformIncomingBiserFiles.readyMethod]);
    await sub.cancel();
  });

  test('файл .biser из ссылки file:// читается; чужие схемы и расширения игнорируются', () async {
    final List<Result<BiserFile>> got = <Result<BiserFile>>[];
    final StreamSubscription<Result<BiserFile>> sub = source().files.listen(got.add);
    links
      ..add(Uri.parse('file:///tmp/Роза.biser'))
      ..add(Uri.parse('https://example.com/a.biser'))
      ..add(Uri.parse('file:///tmp/photo.png'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(got.single.valueOrNull, BiserFile(name: 'Роза.biser', bytes: Uint8List.fromList(<int>[1, 2, 3])));
    expect(readPaths, <String>['/tmp/Роза.biser']);
    await sub.cancel();
  });

  test('пути от macOS приходят через канал', () async {
    final List<Result<BiserFile>> got = <Result<BiserFile>>[];
    final StreamSubscription<Result<BiserFile>> sub = source().files.listen(got.add);
    await Future<void>.delayed(Duration.zero);
    await sendFromPlatform(<String>['/Users/n/a.biser', '/Users/n/b.txt']);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(got.map((r) => r.valueOrNull?.name), <String?>['a.biser']);
    await sub.cancel();
  });

  test('сбой чтения — ошибка в потоке, не исключение', () async {
    final List<Result<BiserFile>> got = <Result<BiserFile>>[];
    final StreamSubscription<Result<BiserFile>> sub = source(failRead: true).files.listen(got.add);
    links.add(Uri.parse('file:///tmp/a.biser'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(got.single.failureOrNull, isA<StorageFailure>());
    await sub.cancel();
  });
}
