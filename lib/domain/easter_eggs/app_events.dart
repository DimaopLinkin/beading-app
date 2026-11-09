import 'dart:async';

import 'package:beading/domain/easter_eggs/app_event.dart';

/// Шина событий приложения. Экраны и use cases кладут события, пасхалки слушают.
class AppEvents {
  final StreamController<AppEvent> _controller = StreamController<AppEvent>.broadcast();

  Stream<AppEvent> get stream => _controller.stream;

  /// После [close] события молча отбрасываются.
  void add(AppEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  Future<void> close() => _controller.close();
}
