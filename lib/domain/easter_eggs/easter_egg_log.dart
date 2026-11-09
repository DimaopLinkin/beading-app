import 'package:beading/core/result.dart';
import 'package:beading/domain/easter_eggs/egg_log_entry.dart';

/// История показанных комплиментов. Локальная, между устройствами не синхронизируется.
abstract interface class EasterEggLog {
  Future<Result<List<EggLogEntry>>> all();

  Future<Result<void>> add(EggLogEntry entry);
}
