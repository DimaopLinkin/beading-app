import 'package:beading/core/result.dart';
import 'package:beading/data/db/app_database.dart';
import 'package:beading/data/db/daos/easter_egg_log_dao.dart';
import 'package:beading/data/settings/storage_guard.dart';
import 'package:beading/domain/easter_eggs/easter_egg_log.dart';
import 'package:beading/domain/easter_eggs/egg_group.dart';
import 'package:beading/domain/easter_eggs/egg_log_entry.dart';

/// Журнал показов в таблице `easter_egg_log`.
class DriftEasterEggLog implements EasterEggLog {
  DriftEasterEggLog(EasterEggLogDao dao) : _dao = dao;

  final EasterEggLogDao _dao;

  @override
  Future<Result<List<EggLogEntry>>> all() => guardStorage<List<EggLogEntry>>(() async {
    final Map<String, EggGroup> groups = <String, EggGroup>{for (final EggGroup g in EggGroup.values) g.name: g};
    return <EggLogEntry>[
      for (final EasterEggLogRow row in await _dao.all())
        // Группа из более новой версии приложения нам неизвестна: пропускаем запись.
        if (groups[row.eggGroup] case final EggGroup group)
          EggLogEntry(group: group, eggId: row.eggId, shownAt: DateTime.fromMillisecondsSinceEpoch(row.shownAt)),
    ];
  });

  @override
  Future<Result<void>> add(EggLogEntry entry) => guardStorage<void>(
    () => _dao.insertRow(
      group: entry.group.name,
      eggId: entry.eggId,
      shownAtMs: entry.shownAt.millisecondsSinceEpoch,
    ),
  );
}
