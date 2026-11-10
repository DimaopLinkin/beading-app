import 'package:beading/core/result.dart';

/// Выполняет несколько записей как одну: если [action] вернул ошибку или бросил исключение,
/// все записи базы внутри откатываются.
abstract interface class UnitOfWork {
  Future<Result<T>> run<T>(Future<Result<T>> Function() action);
}
