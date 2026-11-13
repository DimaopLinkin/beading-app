import 'dart:async';
import 'dart:io';

import 'package:beading/domain/sync/sync_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Вход через Supabase Auth (только почта и пароль).
class SupabaseSyncSession implements SyncSession {
  SupabaseSyncSession(this._auth);

  final GoTrueClient _auth;

  @override
  String? get userId => _auth.currentUser?.id;

  @override
  String? get email => _auth.currentUser?.email;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthRetryableFetchException {
      throw const SyncAuthException(SyncAuthFailure.offline);
    } on AuthException catch (error) {
      final int? status = int.tryParse(error.statusCode ?? '');
      throw SyncAuthException(
        status != null && status >= 500 ? SyncAuthFailure.server : SyncAuthFailure.invalidCredentials,
      );
    } on SocketException {
      throw const SyncAuthException(SyncAuthFailure.offline);
    } on TimeoutException {
      throw const SyncAuthException(SyncAuthFailure.offline);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Обрыв связи, а не отказ сервера. Тип `ClientException` приходит из пакета http, отдельной зависимости на него нет.
bool isNetworkError(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is AuthRetryableFetchException ||
    error.runtimeType.toString() == 'ClientException';
