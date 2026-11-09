/// Принимает событие «нашла секрет» (7 нажатий по логотипу). В приложении это `AppEventsSecretTapHandler`
/// (шлёт `SecretTapped` в поток событий пасхалок); [NoopSecretTapHandler] — для мест, где пасхалки не нужны.
abstract interface class SecretTapHandler {
  void onSecretTapped();
}

class NoopSecretTapHandler implements SecretTapHandler {
  const NoopSecretTapHandler();

  @override
  void onSecretTapped() {}
}
