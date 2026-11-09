/// Типизированный ключ настройки: имя в хранилище, значение по умолчанию и перевод в строку и обратно.
///
/// Имена с префиксом [localPrefix] относятся к устройству: в синхронизацию, экспорт `.biser` и копию базы они не попадают.
final class SettingKey<T> {
  const SettingKey({required this.name, required this.defaultValue, required this.encode, required this.decode});

  static const String localPrefix = 'local.';

  /// Относится ли имя [name] только к этому устройству.
  static bool isLocalName(String name) => name.startsWith(localPrefix);

  /// Имя в таблице `settings`. Менять нельзя: оно хранится на устройствах.
  final String name;

  bool get isLocal => isLocalName(name);
  final T defaultValue;
  // ignore: unsafe_variance, функция только принимает T и вызывается репозиторием с T.
  final String Function(T value) encode;

  /// Возвращает `null`, если строка не разбирается: тогда используется [defaultValue].
  final T? Function(String raw) decode;

  @override
  String toString() => 'SettingKey($name)';
}
