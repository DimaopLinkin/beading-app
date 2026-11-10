import 'package:beading/domain/easter_eggs/egg_group.dart';
import 'package:equatable/equatable.dart';

/// Запись о показанном комплименте (`easter_egg_log`).
final class EggLogEntry extends Equatable {
  const EggLogEntry({required this.group, required this.eggId, required this.shownAt});

  final EggGroup group;

  /// [Compliment.id].
  final String eggId;

  /// Локальное время показа (по `Clock`).
  final DateTime shownAt;

  @override
  List<Object?> get props => <Object?>[group, eggId, shownAt];
}
