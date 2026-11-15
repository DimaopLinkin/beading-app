import 'package:beading/domain/stats/project_pace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('темп и оценка остатка по клеткам', () {
    final ProjectPace? p = ProjectPace.estimate(done: 420, total: 1260, worked: const Duration(hours: 2));
    expect(p, isNotNull);
    expect(p!.perHour, 210);
    expect(p.remaining, const Duration(hours: 4));
  });

  test('мало времени или ничего не сделано: оценки нет', () {
    expect(ProjectPace.estimate(done: 100, total: 1000, worked: const Duration(minutes: 90)), isNull);
    expect(ProjectPace.estimate(done: 0, total: 1000, worked: const Duration(hours: 5)), isNull);
  });

  test('всё сделано: оценки нет', () {
    expect(ProjectPace.estimate(done: 1000, total: 1000, worked: const Duration(hours: 5)), isNull);
  });

  test('ровно два часа уже достаточно, пустая схема — оценки нет', () {
    expect(ProjectPace.estimate(done: 10, total: 100, worked: const Duration(hours: 2)), isNotNull);
    expect(ProjectPace.estimate(done: 0, total: 0, worked: const Duration(hours: 5)), isNull);
  });
}
