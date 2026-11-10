import 'package:beading/core/result.dart';
import 'package:beading/domain/events/app_events.dart';
import 'package:beading/domain/settings/setting_keys.dart';
import 'package:beading/domain/settings/settings_repository.dart';

/// Счётчик отмеченных рядов за всё время. Каждая отмеченная строка шлёт [RowsCompleted] с новым итогом;
/// снятая отметка итог уменьшает, чтобы «ряд назад и снова вперёд» не считался дважды.
class RowsCounter {
  const RowsCounter({required SettingsRepository settings, required AppEvents events})
    : _settings = settings,
      _events = events;

  final SettingsRepository _settings;
  final AppEvents _events;

  /// Отмечен ещё один ряд.
  Future<Result<int>> completed() async {
    final Result<int> next = await _shift(1);
    if (next case Success<int>(:final int value)) {
      _events.publish(RowsCompleted(value));
    }
    return next;
  }

  /// Отметка ряда снята.
  Future<Result<int>> undone() => _shift(-1);

  Future<Result<int>> _shift(int delta) async {
    final Result<int> current = await _settings.read<int>(SettingKeys.rowsCompleted);
    if (current case Err<int>()) {
      return current;
    }
    final int next = (current.valueOrNull! + delta).clamp(0, 1 << 30);
    final Result<void> saved = await _settings.write<int>(SettingKeys.rowsCompleted, next);
    return switch (saved) {
      Err<void>(:final failure) => Err<int>(failure),
      Success<void>() => Success<int>(next),
    };
  }
}
