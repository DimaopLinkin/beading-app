import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/settings/secret_tap_handler.dart';

/// Шлёт `SecretTapped` в шину событий: пасхалка «секрет» показывает комплимент.
class AppEventsSecretTapHandler implements SecretTapHandler {
  const AppEventsSecretTapHandler(this._events);

  final AppEvents _events;

  @override
  void onSecretTapped() => _events.publish(const SecretTapped());
}
