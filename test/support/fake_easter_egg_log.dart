import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/easter_eggs/easter_egg_log.dart';
import 'package:beading/domain/easter_eggs/egg_log_entry.dart';

/// Фейковая история показов в памяти; [failing] — все операции возвращают ошибку хранилища.
class FakeEasterEggLog implements EasterEggLog {
  FakeEasterEggLog({this.failing = false});

  final List<EggLogEntry> entries = <EggLogEntry>[];
  bool failing;

  @override
  Future<Result<List<EggLogEntry>>> all() async =>
      failing ? const Err<List<EggLogEntry>>(StorageFailure('boom')) : Success<List<EggLogEntry>>(List.of(entries));

  @override
  Future<Result<void>> add(EggLogEntry entry) async {
    if (failing) {
      return const Err<void>(StorageFailure('boom'));
    }
    entries.add(entry);
    return const Success<void>(null);
  }
}
