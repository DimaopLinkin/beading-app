import 'dart:async';

import 'package:beading/domain/easter_eggs/shown_compliment.dart';
import 'package:beading/presentation/easter_eggs/compliment_banner_cubit.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('сначала баннера нет', () {
    final StreamController<ShownCompliment> source = StreamController<ShownCompliment>();
    final ComplimentBannerCubit cubit = ComplimentBannerCubit(source.stream);
    addTearDown(source.close);
    addTearDown(cubit.close);

    expect(cubit.state, isNull);
  });

  test('показывает комплимент и убирает его через 5 секунд', () {
    fakeAsync((async) {
      final StreamController<ShownCompliment> source = StreamController<ShownCompliment>();
      final ComplimentBannerCubit cubit = ComplimentBannerCubit(source.stream);

      source.add(const ShownCompliment('Привет'));
      async.flushMicrotasks();
      expect(cubit.state, const ShownCompliment('Привет'));

      async.elapse(const Duration(milliseconds: 4999));
      expect(cubit.state, isNotNull);
      async.elapse(const Duration(milliseconds: 1));
      expect(cubit.state, isNull);

      unawaited(cubit.close());
      unawaited(source.close());
    });
  });

  test('dismiss убирает баннер сразу и гасит таймер', () {
    fakeAsync((async) {
      final StreamController<ShownCompliment> source = StreamController<ShownCompliment>();
      final ComplimentBannerCubit cubit = ComplimentBannerCubit(source.stream);

      source.add(const ShownCompliment('Привет'));
      async.flushMicrotasks();
      cubit.dismiss();

      expect(cubit.state, isNull);
      expect(async.pendingTimers, isEmpty);

      unawaited(cubit.close());
      unawaited(source.close());
    });
  });

  test('новый комплимент заменяет старый и заново отсчитывает 5 секунд', () {
    fakeAsync((async) {
      final StreamController<ShownCompliment> source = StreamController<ShownCompliment>();
      final ComplimentBannerCubit cubit = ComplimentBannerCubit(source.stream);

      source.add(const ShownCompliment('Первый'));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      source.add(const ShownCompliment('Второй'));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));

      expect(cubit.state, const ShownCompliment('Второй'));

      unawaited(cubit.close());
      unawaited(source.close());
    });
  });

  test('close отменяет таймер', () {
    fakeAsync((async) {
      final StreamController<ShownCompliment> source = StreamController<ShownCompliment>();
      final ComplimentBannerCubit cubit = ComplimentBannerCubit(source.stream);
      source.add(const ShownCompliment('Привет'));
      async.flushMicrotasks();

      unawaited(cubit.close());
      async.flushMicrotasks();

      expect(async.pendingTimers, isEmpty);
      unawaited(source.close());
    });
  });
}
