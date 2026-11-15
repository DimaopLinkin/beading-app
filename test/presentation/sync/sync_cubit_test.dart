import 'dart:io';

import 'package:beading/core/clock.dart';
import 'package:beading/domain/sync/sync_engine.dart';
import 'package:beading/domain/sync/sync_remote.dart';
import 'package:beading/domain/sync/sync_session.dart';
import 'package:beading/presentation/sync/sync_cubit.dart';
import 'package:beading/presentation/sync/sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/sync/sync_fakes.dart';

class _Clock implements Clock {
  @override
  DateTime now() => DateTime(2026, 11, 13, 9, 5);
}

class _Session implements SyncSession {
  _Session({this.userId, this.failure});

  @override
  String? userId;
  SyncAuthFailure? failure;

  @override
  String? get email => userId == null ? null : 'a@b.c';

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (failure != null) throw SyncAuthException(failure!);
    userId = 'u1';
  }

  @override
  Future<void> signOut() async => userId = null;
}

class _ThrowingRemote extends FakeRemote {
  Exception? error;

  @override
  Future<SyncPage> pullSince(int cursor, {int limit = 500}) {
    if (error != null) throw error!;
    return super.pullSince(cursor, limit: limit);
  }
}

void main() {
  late FakeStore store;
  late _ThrowingRemote remote;

  SyncCubit build(_Session session) => SyncCubit(
    session: session,
    engine: SyncEngine(store: store, remote: remote, schema: testSchema()),
    clock: _Clock(),
    isNetworkError: (e) => e is SocketException,
  );

  setUp(() {
    store = FakeStore();
    remote = _ThrowingRemote();
  });

  test('вход и первый цикл: статус с временем, без ошибки', () async {
    final SyncCubit cubit = build(_Session());
    await cubit.signIn(email: 'a@b.c', password: 'x');
    expect(cubit.state.signedIn, isTrue);
    expect(cubit.state.problem, isNull);
    expect(cubit.state.lastSyncedAt, DateTime(2026, 11, 13, 9, 5));
    expect(await store.readOwner(), 'u1');
    await cubit.close();
  });

  test('неверный пароль и нет сети при входе', () async {
    final _Session session = _Session(failure: SyncAuthFailure.invalidCredentials);
    final SyncCubit cubit = build(session);
    await cubit.signIn(email: 'a', password: 'b');
    expect(cubit.state.problem, SyncProblem.invalidCredentials);
    expect(cubit.state.signedIn, isFalse);
    session.failure = SyncAuthFailure.offline;
    await cubit.signIn(email: 'a', password: 'b');
    expect(cubit.state.problem, SyncProblem.offline);
    await cubit.close();
  });

  test('ошибки цикла: сеть, чужой аккаунт, прочее', () async {
    final SyncCubit cubit = build(_Session(userId: 'u1'));
    remote.error = const SocketException('x');
    await cubit.syncNow();
    expect(cubit.state.problem, SyncProblem.offline);
    remote.error = Exception('x');
    await cubit.syncNow();
    expect(cubit.state.problem, SyncProblem.failed);
    remote.error = null;
    await store.writeOwner('other');
    await cubit.syncNow();
    expect(cubit.state.problem, SyncProblem.ownerMismatch);
    await cubit.close();
  });

  test('без входа цикл не запускается; выход очищает состояние', () async {
    final SyncCubit cubit = build(_Session());
    await cubit.syncNow();
    expect(cubit.state, const SyncState());
    final SyncCubit signed = build(_Session(userId: 'u1'));
    await signed.syncNow();
    await signed.signOut();
    expect(signed.state, const SyncState());
    await cubit.close();
    await signed.close();
  });
}
