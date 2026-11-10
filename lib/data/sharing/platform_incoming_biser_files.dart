import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Файлы `.biser`, открытые системой в приложении.
///
/// iOS: ссылки с файлом приходят через `app_links` (схема `file`). macOS: `app_links` файлы не отдаёт,
/// поэтому нативный `AppDelegate` шлёт пути каналом `app.beading/incoming_files`:
/// платформа → Dart `openFiles` со списком путей; Dart → платформа `ready` — «слушаю, пришли накопленное».
class PlatformIncomingBiserFiles implements IncomingBiserFiles {
  /// В тестах подменяют все три источника.
  PlatformIncomingBiserFiles({
    Stream<Uri>? links,
    MethodChannel? channel,
    Future<Uint8List> Function(String path)? read,
  }) : _links = links,
       _channel = channel ?? const MethodChannel(channelName),
       _read = read ?? ((path) => File(path).readAsBytes());

  static const String channelName = 'app.beading/incoming_files';
  static const String openMethod = 'openFiles';
  static const String readyMethod = 'ready';
  static const String extension = '.biser';

  final Stream<Uri>? _links;
  final MethodChannel _channel;
  final Future<Uint8List> Function(String path) _read;

  @override
  Stream<Result<BiserFile>> get files {
    StreamSubscription<Uri>? linkSubscription;
    // ignore: close_sinks, контроллер живёт, пока на поток подписаны, и уходит вместе с ним.
    late final StreamController<Result<BiserFile>> controller;
    controller = StreamController<Result<BiserFile>>(
      onListen: () {
        Future<void> handle(String path) async {
          if (!path.toLowerCase().endsWith(extension)) {
            return;
          }
          try {
            controller.add(Success<BiserFile>(BiserFile(name: p.basename(path), bytes: await _read(path))));
          } on Object catch (error) {
            controller.add(Err<BiserFile>(StorageFailure('Не удалось открыть файл: $error')));
          }
        }

        _channel.setMethodCallHandler((call) async {
          if (call.method == openMethod && call.arguments is List<Object?>) {
            for (final Object? path in call.arguments as List<Object?>) {
              if (path is String) {
                await handle(path);
              }
            }
          }
        });
        unawaited(_announceReady());
        try {
          // app_links отдаёт файлы только на iOS; на остальных платформах плагина может не быть вовсе.
          final Stream<Uri>? links =
              _links ?? (defaultTargetPlatform == TargetPlatform.iOS ? AppLinks().uriLinkStream : null);
          linkSubscription = links?.listen((uri) {
            if (uri.scheme == 'file') {
              unawaited(handle(uri.toFilePath()));
            }
          }, onError: (Object _) {});
        } on Object {
          // Платформа без app_links (тесты, настольная заглушка): остаётся только канал.
        }
      },
      onCancel: () async {
        _channel.setMethodCallHandler(null);
        await linkSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> _announceReady() async {
    try {
      await _channel.invokeMethod<void>(readyMethod);
    } on MissingPluginException {
      // iOS и тесты: нативной части канала нет.
    } on PlatformException {
      // Нечего забирать.
    }
  }
}
