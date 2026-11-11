import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_session.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';

/// Запускает конвейер в долгоживущем изоляте с [ImageToGridSession] (T58): расчёт не подвешивает интерфейс, а стадии,
/// чьи входные данные не изменились, берутся из кеша изолята.
///
/// Картинка и маска важности копируются в изолят один раз, при первом запросе с ними; следующие запросы с тем же
/// объектом картинки уходят без пикселей. Изолят поднимается при первом расчёте и живёт до [release].
final class IsolateImageToGridRunner implements ImageToGridRunner {
  IsolateImageToGridRunner({ImageToGridPipeline pipeline = const ImageToGridPipeline()}) : _pipeline = pipeline;

  final ImageToGridPipeline _pipeline;

  Future<SendPort>? _worker;
  ReceivePort? _replies;
  Isolate? _isolate;
  final Map<int, Completer<GeneratedPattern>> _pending = <int, Completer<GeneratedPattern>>{};
  int _nextId = 0;

  /// Номер сессии: растёт при [release], чтобы изолят, поднимавшийся во время release, не остался жить.
  int _epoch = 0;

  SourceImage? _sentImage;
  Float32List? _sentImportance;
  Uint8List? _sentMask;

  /// Картинка-заглушка в запросах без пикселей.
  static final SourceImage _placeholder = SourceImage(width: 1, height: 1, rgba: Uint8List(4));

  @override
  Future<GeneratedPattern> run(ImageToGridRequest request) async {
    final SendPort worker = await _start();
    final bool carriesImage =
        !identical(request.image, _sentImage) ||
        !identical(request.importance, _sentImportance) ||
        !identical(request.subjectMask, _sentMask);
    _sentImage = request.image;
    _sentImportance = request.importance;
    _sentMask = request.subjectMask;
    final int id = _nextId++;
    final Completer<GeneratedPattern> completer = Completer<GeneratedPattern>();
    _pending[id] = completer;
    worker.send(
      _Job(id, carriesImage ? request : request.withSource(image: _placeholder), carriesImage: carriesImage),
    );
    return completer.future;
  }

  @override
  Future<void> release() async {
    _epoch++;
    _worker = null;
    _sentImage = null;
    _sentImportance = null;
    _sentMask = null;
    _replies?.close();
    _replies = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _failPending('Сессия расчёта закрыта');
  }

  void _failPending(String reason) {
    final StateError error = StateError(reason);
    for (final Completer<GeneratedPattern> pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(error);
    }
    _pending.clear();
  }

  Future<SendPort> _start() => _worker ??= _spawn();

  Future<SendPort> _spawn() async {
    final int epoch = _epoch;
    final ReceivePort replies = ReceivePort();
    _replies = replies;
    final Completer<SendPort> ready = Completer<SendPort>();
    replies.listen((message) {
      if (message is SendPort) {
        ready.complete(message);
      } else if (message == null || message is List) {
        // Изолят завершился или упал вне задания: ждать ответов не от кого, следующий запуск поднимет новый.
        if (epoch == _epoch) {
          _worker = null;
          _failPending('Расчёт прерван');
        }
      } else if (message is _Done) {
        final Completer<GeneratedPattern>? pending = _pending.remove(message.id);
        if (pending == null || pending.isCompleted) return;
        final GeneratedPattern? pattern = message.pattern;
        if (pattern != null) {
          pending.complete(pattern);
        } else {
          pending.completeError(StateError(message.error ?? 'Расчёт не удался'));
        }
      }
    });
    final ImageToGridPipeline pipeline = _pipeline;
    final Isolate isolate = await Isolate.spawn(
      _serve,
      (replies.sendPort, pipeline),
      onError: replies.sendPort,
      onExit: replies.sendPort,
    );
    if (epoch != _epoch) {
      // Сессию закрыли, пока изолят поднимался.
      isolate.kill(priority: Isolate.immediate);
      throw StateError('Сессия расчёта закрыта');
    }
    _isolate = isolate;
    return ready.future;
  }
}

final class _Job {
  const _Job(this.id, this.request, {required this.carriesImage});

  final int id;
  final ImageToGridRequest request;
  final bool carriesImage;
}

final class _Done {
  const _Done(this.id, {this.pattern, this.error});

  final int id;
  final GeneratedPattern? pattern;
  final String? error;
}

/// Точка входа изолята: ждёт задания, считает через одну [ImageToGridSession], отвечает по номеру задания.
void _serve((SendPort, ImageToGridPipeline) args) {
  final (SendPort reply, ImageToGridPipeline pipeline) = args;
  final ReceivePort jobs = ReceivePort();
  reply.send(jobs.sendPort);
  final ImageToGridSession session = ImageToGridSession(pipeline: pipeline);
  SourceImage? image;
  Float32List? importance;
  Uint8List? subjectMask;
  jobs.listen((message) {
    if (message is! _Job) return;
    try {
      if (message.carriesImage) {
        image = message.request.image;
        importance = message.request.importance;
        subjectMask = message.request.subjectMask;
      }
      final SourceImage? held = image;
      final ImageToGridRequest request = held == null
          ? message.request
          : message.request.withSource(image: held, importance: importance, subjectMask: subjectMask);
      reply.send(_Done(message.id, pattern: session.run(request)));
    } on Object catch (error) {
      reply.send(_Done(message.id, error: error.toString()));
    }
  });
}
