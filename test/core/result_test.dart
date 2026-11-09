import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Success хранит значение', () {
      const Result<int> result = Success<int>(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Err хранит ошибку', () {
      const Result<int> result = Err<int>(UnexpectedFailure('boom'));

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, const UnexpectedFailure('boom'));
    });

    test('map преобразует только успех', () {
      const Result<int> ok = Success<int>(2);
      const Result<int> bad = Err<int>(NotFoundFailure('x'));

      expect(ok.map((v) => v * 10), const Success<int>(20));
      expect(bad.map((v) => v * 10), const Err<int>(NotFoundFailure('x')));
    });

    test('fold вызывает ветку, соответствующую результату', () {
      const Result<int> ok = Success<int>(1);
      const Result<int> bad = Err<int>(ValidationFailure('пусто'));

      expect(ok.fold(onSuccess: (v) => 'ok $v', onFailure: (f) => 'err'), 'ok 1');
      expect(bad.fold(onSuccess: (v) => 'ok', onFailure: (f) => f.message), 'пусто');
    });

    test('равенство по значению', () {
      expect(const Success<int>(1), const Success<int>(1));
      expect(const Success<int>(1), isNot(const Success<int>(2)));
      expect(const Success<int>(1).hashCode, const Success<int>(1).hashCode);
      expect(const Err<int>(UnexpectedFailure('a')), isNot(const Err<int>(UnexpectedFailure('b'))));
    });

    test('разные виды Failure не равны при одинаковом сообщении', () {
      expect(const NotFoundFailure('a'), isNot(const ValidationFailure('a')));
    });
  });
}
