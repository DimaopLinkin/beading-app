import 'package:equatable/equatable.dart';

/// Промежуток времени, в который работали над проектом. Нить плетения прерывается паузой (уход в фон) — тогда сессия
/// заканчивается, а при возвращении начинается новая.
final class WorkSession extends Equatable {
  const WorkSession({required this.id, required this.projectId, required this.startedAt, this.endedAt});

  final String id;
  final String projectId;

  /// UTC.
  final DateTime startedAt;

  /// Последний известный момент работы. `null` — сессия только что началась и ещё ни разу не обновлялась.
  final DateTime? endedAt;

  /// Сколько длилась сессия ; сессия, которую не успели обновить, считается нулевой.
  Duration get duration => endedAt == null ? Duration.zero : endedAt!.difference(startedAt);

  @override
  List<Object?> get props => <Object?>[id, projectId, startedAt, endedAt];
}
