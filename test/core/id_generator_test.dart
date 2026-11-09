import 'dart:math';

import 'package:beading/core/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_clock.dart';

void main() {
  final RegExp v7Format = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  UuidV7IdGenerator create(FakeClock clock, {int seed = 1}) => UuidV7IdGenerator(clock: clock, random: Random(seed));

  test('формат: UUID версии 7, вариант RFC 4122', () {
    final UuidV7IdGenerator generator = create(FakeClock(DateTime.utc(2026, 11, 9)));

    for (int i = 0; i < 100; i++) {
      expect(generator.next(), matches(v7Format));
    }
  });

  test('первые 48 бит — время в миллисекундах', () {
    final DateTime time = DateTime.utc(2026, 11, 9, 12, 30, 15, 123);
    final String id = create(FakeClock(time)).next();

    final int timestamp = int.parse(id.replaceAll('-', '').substring(0, 12), radix: 16);
    expect(timestamp, time.millisecondsSinceEpoch);
  });

  test('монотонность в пределах одной миллисекунды', () {
    final UuidV7IdGenerator generator = create(FakeClock(DateTime.utc(2026)));

    final List<String> ids = List<String>.generate(5000, (_) => generator.next());

    expect(ids.toSet(), hasLength(ids.length));
    expect(ids, orderedEquals(<String>[...ids]..sort()));
  });

  test('монотонность при росте времени', () {
    final FakeClock clock = FakeClock(DateTime.utc(2026));
    final UuidV7IdGenerator generator = create(clock);

    final List<String> ids = <String>[];
    for (int i = 0; i < 50; i++) {
      ids
        ..add(generator.next())
        ..add(generator.next());
      clock.advance(const Duration(milliseconds: 1));
    }

    expect(ids, orderedEquals(<String>[...ids]..sort()));
  });

  test('монотонность, если часы пошли назад', () {
    final FakeClock clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
    final UuidV7IdGenerator generator = create(clock);

    final String first = generator.next();
    clock.set(DateTime.utc(2026, 1, 1, 11));
    final String second = generator.next();

    expect(second.compareTo(first), greaterThan(0));
  });

  test('после переполнения счётчика и отката часов id продолжают расти', () {
    final FakeClock clock = FakeClock(DateTime.utc(2026));
    final UuidV7IdGenerator generator = create(clock);

    final List<String> ids = List<String>.generate(5000, (_) => generator.next());
    clock.set(DateTime.utc(2025));
    ids.addAll(List<String>.generate(10, (_) => generator.next()));

    expect(ids, orderedEquals(<String>[...ids]..sort()));
    expect(ids.toSet(), hasLength(ids.length));
    final int firstMillis = int.parse(ids.first.replaceAll('-', '').substring(0, 12), radix: 16);
    final int lastMillis = int.parse(ids.last.replaceAll('-', '').substring(0, 12), radix: 16);
    expect(lastMillis, greaterThan(firstMillis));
  });

  test('одинаковые зерно и время дают одинаковые id, разные зёрна — разные', () {
    final DateTime time = DateTime.utc(2026);

    expect(create(FakeClock(time)).next(), create(FakeClock(time)).next());
    expect(create(FakeClock(time)).next(), isNot(create(FakeClock(time), seed: 2).next()));
  });

  test('по умолчанию создаётся с системными часами', () {
    expect(UuidV7IdGenerator().next(), matches(v7Format));
  });
}
