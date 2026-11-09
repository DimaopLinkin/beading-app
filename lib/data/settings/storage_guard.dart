import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:sqlite3/sqlite3.dart';

/// Граница `data`: превращает исключения хранилища в [StorageFailure].
Future<Result<T>> guardStorage<T>(Future<T> Function() action) async {
  try {
    return Success<T>(await action());
  } on DriftWrappedException catch (error) {
    return Err<T>(StorageFailure('$error'));
  } on DriftRemoteException catch (error) {
    return Err<T>(StorageFailure('$error'));
  } on SqliteException catch (error) {
    return Err<T>(StorageFailure('$error'));
  } on InvalidDataException catch (error) {
    return Err<T>(StorageFailure('$error'));
  }
}
