import 'dart:async';

import 'package:beading/core/clock.dart';
import 'package:beading/domain/sync/sync_engine.dart';
import 'package:beading/domain/sync/sync_session.dart';
import 'package:beading/presentation/sync/sync_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Вход и циклы синхронизации (ADR-0006). Один на приложение: [start] запускает первый цикл и таймер,
/// [onResumed] — цикл при возвращении в приложение. Параллельных циклов не бывает.
class SyncCubit extends Cubit<SyncState> {
  SyncCubit({
    required SyncSession session,
    required SyncEngine engine,
    required Clock clock,
    required bool Function(Object error) isNetworkError,
    this.interval = const Duration(minutes: 1),
    Stream<void>? wakes,
  }) : _session = session,
       _engine = engine,
       _clock = clock,
       _isNetworkError = isNetworkError,
       _wakes = wakes,
       super(SyncState(email: session.userId == null ? null : session.email ?? ''));

  final SyncSession _session;
  final SyncEngine _engine;
  final Clock _clock;
  final bool Function(Object error) _isNetworkError;
  final Duration interval;
  final Stream<void>? _wakes;
  StreamSubscription<void>? _wakeSub;
  Timer? _timer;
  Timer? _debounce;

  /// Событие пришло во время цикла: после него нужен ещё один.
  bool _again = false;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(syncNow()));
    _wakeSub ??= _wakes?.listen((_) => _wake());
    unawaited(syncNow());
  }

  Future<void> onResumed() => syncNow();

  /// Короткая пауза склеивает пачку событий (свой же push тоже приходит событием).
  void _wake() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 1), () => unawaited(syncNow()));
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, problem: null));
    try {
      await _session.signIn(email: email, password: password);
    } on SyncAuthException catch (error) {
      emit(
        state.copyWith(
          busy: false,
          problem: switch (error.failure) {
            SyncAuthFailure.invalidCredentials => SyncProblem.invalidCredentials,
            SyncAuthFailure.offline => SyncProblem.offline,
            SyncAuthFailure.server => SyncProblem.server,
          },
        ),
      );
      return;
    }
    emit(state.copyWith(email: _session.email ?? email.trim(), busy: false));
    await syncNow();
  }

  /// Чужие данные на устройстве заменяются данными вошедшего аккаунта, затем идёт обычный цикл.
  Future<void> replaceLocalData() async {
    // Только после явного выбора на экране «чужой аккаунт»: без этой ошибки данные устройства не трогаются.
    if (state.busy || state.problem != SyncProblem.ownerMismatch) return;
    emit(state.copyWith(busy: true));
    await _engine.discardLocalData();
    emit(state.copyWith(busy: false, problem: null));
    await syncNow();
  }

  Future<void> signOut() async {
    await _session.signOut();
    emit(const SyncState());
  }

  Future<void> syncNow() async {
    final String? userId = _session.userId;
    if (userId == null || isClosed) return;
    if (state.busy) {
      _again = true;
      return;
    }
    emit(state.copyWith(busy: true, email: _session.email ?? state.email ?? ''));
    try {
      final SyncReport report = await _engine.run(userId: userId);
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          lastSyncedAt: _clock.now(),
          problem: report.needsAppUpdate ? SyncProblem.needsAppUpdate : null,
        ),
      );
    } on SyncOwnerMismatch {
      _again = false;
      if (!isClosed) emit(state.copyWith(busy: false, problem: SyncProblem.ownerMismatch));
    } on Object catch (error) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, problem: _isNetworkError(error) ? SyncProblem.offline : SyncProblem.failed));
      }
    }
    if (_again && !isClosed) {
      final bool failed = state.problem != null;
      _again = false;
      if (!failed) await syncNow();
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _debounce?.cancel();
    unawaited(_wakeSub?.cancel());
    return super.close();
  }
}
