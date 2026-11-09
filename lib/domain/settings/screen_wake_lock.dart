/// Запрет гашения экрана. Реализация платформенная (см. `data/platform`).
abstract interface class ScreenWakeLock {
  Future<void> enable();

  Future<void> disable();
}
