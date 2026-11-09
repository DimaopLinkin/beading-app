/// Принимает событие «нашла секрет» (7 нажатий по логотипу). T08 подставит реализацию, которая шлёт `SecretTapped`
/// в поток событий пасхалок; до тех пор — [NoopSecretTapHandler].
abstract interface class SecretTapHandler {
  void onSecretTapped();
}

class NoopSecretTapHandler implements SecretTapHandler {
  const NoopSecretTapHandler();

  @override
  void onSecretTapped() {}
}
