import 'dart:async';

/// Событие приложения для подписчиков вроде пасхалок. Новые виды добавляют задачи, которым они нужны.
sealed class AppEvent {
  const AppEvent();
}

/// Проект перешёл в статус «готово».
final class ProjectCompleted extends AppEvent {
  const ProjectCompleted(this.projectId);

  final String projectId;
}

/// Шина событий: публикуем в одном месте, слушаем в другом.
abstract interface class AppEvents {
  Stream<AppEvent> get stream;

  void publish(AppEvent event);
}

/// Шина в памяти: события получают только те, кто подписан в момент публикации.
class BroadcastAppEvents implements AppEvents {
  final StreamController<AppEvent> _controller = StreamController<AppEvent>.broadcast(sync: true);

  @override
  Stream<AppEvent> get stream => _controller.stream;

  @override
  void publish(AppEvent event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}
