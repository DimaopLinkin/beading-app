import 'package:equatable/equatable.dart';

/// Ошибка, которую use case возвращает вместо исключения.
sealed class Failure extends Equatable {
  const Failure(this.message);

  /// Описание для разработчика, не для показа пользователю.
  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// Сущность не найдена.
final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Входные данные не прошли проверку.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Ошибка хранилища или файловой системы.
final class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

/// Всё остальное, чего не ждали.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
