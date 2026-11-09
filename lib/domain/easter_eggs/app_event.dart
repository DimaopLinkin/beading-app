import 'package:equatable/equatable.dart';

/// Событие приложения, на которое может отреагировать пасхалка.
sealed class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Приложение запущено.
final class AppStarted extends AppEvent {
  const AppStarted();
}

/// Проект отмечен как «готово».
final class ProjectCompleted extends AppEvent {
  const ProjectCompleted();
}

/// Отмечен ряд. [total] — сколько рядов отмечено за всё время (после этого ряда).
final class RowsCompleted extends AppEvent {
  const RowsCompleted(this.total);

  final int total;

  @override
  List<Object?> get props => <Object?>[total];
}

/// Сессия идёт дольше порога ([EasterEggPolicy.longSession]).
final class LongSession extends AppEvent {
  const LongSession();
}

/// Секрет: 7 нажатий на логотип в «О приложении».
final class SecretTapped extends AppEvent {
  const SecretTapped();
}
