import 'package:beading/domain/events/app_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('подписчики получают события, опоздавшие — нет', () {
    final BroadcastAppEvents events = BroadcastAppEvents();
    addTearDown(events.dispose);
    events.publish(const ProjectCompleted('раньше'));
    final List<AppEvent> first = <AppEvent>[];
    final List<AppEvent> second = <AppEvent>[];
    events.stream.listen(first.add);
    events.stream.listen(second.add);
    events.publish(const ProjectCompleted('p1'));
    expect(first.map((e) => (e as ProjectCompleted).projectId), <String>['p1']);
    expect(second, hasLength(1));
  });
}
