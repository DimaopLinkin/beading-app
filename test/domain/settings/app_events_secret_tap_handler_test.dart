import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/settings/app_events_secret_tap_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onSecretTapped публикует SecretTapped', () {
    final BroadcastAppEvents events = BroadcastAppEvents();
    addTearDown(events.dispose);
    final List<AppEvent> received = <AppEvent>[];
    events.stream.listen(received.add);

    AppEventsSecretTapHandler(events).onSecretTapped();

    expect(received.single, isA<SecretTapped>());
  });
}
