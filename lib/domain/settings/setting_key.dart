/// Типизированный ключ настройки: имя в хранилище, значение по умолчанию и перевод в строку и обратно.
///
/// Имена с префиксом `local.` относятся к устройству и в синхронизацию не попадают.
final class SettingKey<T> {
  const SettingKey({required this.name, required this.defaultValue, required this.encode, required this.decode});

  /// Имя в таблице `settings`. Менять нельзя: оно хранится на устройствах.
  final String name;
  final T defaultValue;
  // ignore: unsafe_variance, функция только принимает T и вызывается репозиторием с T.
  final String Function(T value) encode;

  /// Возвращает `null`, если строка не разбирается: тогда используется [defaultValue].
  final T? Function(String raw) decode;

  @override
  String toString() => 'SettingKey($name)';
}
