import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/sharing/unit_of_work.dart';

/// Транзакция drift: репозитории на этой же базе участвуют в ней сами (зона транзакции).
class DriftUnitOfWork implements UnitOfWork {
  const DriftUnitOfWork(this._db);

  final AppDatabase _db;

  @override
  Future<Result<T>> run<T>(Future<Result<T>> Function() action) async {
    try {
      final Result<Result<T>> guarded = await guardStorage<Result<T>>(
        () => _db.transaction(() async {
          final Result<T> result = await action();
          if (result case Err<T>(:final Failure failure)) {
            throw _Rollback(failure);
          }
          return result;
        }),
      );
      return guarded.fold(onSuccess: (inner) => inner, onFailure: Err<T>.new);
    } on _Rollback catch (rollback) {
      return Err<T>(rollback.failure);
    }
  }
}

final class _Rollback implements Exception {
  const _Rollback(this.failure);

  final Failure failure;
}
