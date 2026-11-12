import 'package:beading/domain/sync/sync_record.dart';

/// Описание синхронизируемой сущности: порядок применения, поддерживаемая версия формата, родитель.
class SyncEntitySpec {
  const SyncEntitySpec({required this.name, required this.rank, this.supportedVersion = 1, this.parentOf});

  final String name;

  /// Родители применяются раньше детей: меньший [rank] — раньше.
  final int rank;

  /// Новейшая версия формата `data.v`, которую умеет читать это приложение.
  final int supportedVersion;

  /// Ключ родителя (`entity/syncId`) или `null`, если родителя нет.
  final String? Function(SyncRecord record)? parentOf;
}

/// Набор сущностей, участвующих в синхронизации.
class SyncSchema {
  SyncSchema(Iterable<SyncEntitySpec> specs)
    : _specs = <String, SyncEntitySpec>{for (final SyncEntitySpec s in specs) s.name: s};

  final Map<String, SyncEntitySpec> _specs;

  SyncEntitySpec? specOf(String entity) => _specs[entity];

  /// Отпечаток поддерживаемых версий. Меняется после обновления приложения, если версия любой сущности выросла.
  String get fingerprint {
    final List<String> names = _specs.keys.toList()..sort();
    return names.map((n) => '$n:${_specs[n]!.supportedVersion}').join(',');
  }
}
