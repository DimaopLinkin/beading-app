import 'package:beading/core/failure.dart';
import 'package:equatable/equatable.dart';

/// Результат операции: успех со значением или [Failure].
sealed class Result<T> extends Equatable {
  const Result();

  bool get isSuccess => this is Success<T>;

  bool get isFailure => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Success<T>(:final T value) => value,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Err<T>(:final Failure failure) => failure,
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final T value) => Success<R>(transform(value)),
    Err<T>(:final Failure failure) => Err<R>(failure),
  };

  R fold<R>({required R Function(T value) onSuccess, required R Function(Failure failure) onFailure}) => switch (this) {
    Success<T>(:final T value) => onSuccess(value),
    Err<T>(:final Failure failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  List<Object?> get props => <Object?>[value];
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}
