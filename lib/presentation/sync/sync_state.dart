import 'package:flutter/foundation.dart';

/// Что не так с синхронизацией. `null` в [SyncState.problem] — всё хорошо.
enum SyncProblem { invalidCredentials, offline, server, ownerMismatch, needsAppUpdate, failed }

@immutable
class SyncState {
  const SyncState({this.email, this.busy = false, this.lastSyncedAt, this.problem});

  /// Почта вошедшего; `null` — не вошли.
  final String? email;
  final bool busy;
  final DateTime? lastSyncedAt;
  final SyncProblem? problem;

  bool get signedIn => email != null;

  SyncState copyWith({
    Object? email = _keep,
    bool? busy,
    Object? lastSyncedAt = _keep,
    Object? problem = _keep,
  }) => SyncState(
    email: identical(email, _keep) ? this.email : email as String?,
    busy: busy ?? this.busy,
    lastSyncedAt: identical(lastSyncedAt, _keep) ? this.lastSyncedAt : lastSyncedAt as DateTime?,
    problem: identical(problem, _keep) ? this.problem : problem as SyncProblem?,
  );

  static const Object _keep = Object();

  @override
  bool operator ==(Object other) =>
      other is SyncState &&
      other.email == email &&
      other.busy == busy &&
      other.lastSyncedAt == lastSyncedAt &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(email, busy, lastSyncedAt, problem);
}
