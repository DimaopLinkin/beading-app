import 'package:beading/core/result.dart';
import 'package:beading/domain/settings/setting_key.dart';

/// Хранилище настроек с типизированными ключами ([SettingKeys]).
abstract interface class SettingsRepository {
  /// Текущее значение; если не задано или повреждено — [SettingKey.defaultValue].
  Future<Result<T>> read<T>(SettingKey<T> key);

  Future<Result<void>> write<T>(SettingKey<T> key, T value);

  /// Возвращает настройку к значению по умолчанию.
  Future<Result<void>> reset<T>(SettingKey<T> key);

  /// Текущее значение сразу и каждое следующее при изменении. Ошибки хранилища приходят как ошибки потока (не `Result`): у потока нет единственного исхода.
  Stream<T> watch<T>(SettingKey<T> key);
}
