/// Почему вход не удался.
enum SyncAuthFailure { invalidCredentials, offline, server }

class SyncAuthException implements Exception {
  const SyncAuthException(this.failure);

  final SyncAuthFailure failure;

  @override
  String toString() => 'SyncAuthException($failure)';
}

/// Учётная запись синхронизации (ADR-0006): почта и пароль, регистрации и сброса в приложении нет.
abstract interface class SyncSession {
  /// Id вошедшего пользователя; `null`, если не вошли.
  String? get userId;

  String? get email;

  /// Бросает [SyncAuthException].
  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}
