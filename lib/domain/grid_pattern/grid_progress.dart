import 'package:equatable/equatable.dart';

/// Прогресс по схеме: отмеченные ряды и «где я остановилась».
///
/// Номера рядов — по сетке сверху вниз, с нуля; бусины — по ряду слева направо, с нуля. Ряды — множество:
/// при синхронизации отметки двух устройств объединяются. Прогресс по клеткам вышивки добавит T38 отдельно.
final class GridProgress extends Equatable {
  GridProgress({Set<int> completedRows = const <int>{}, this.currentRow, this.currentBead})
    : completedRows = Set<int>.unmodifiable(completedRows);

  const GridProgress.empty() : completedRows = const <int>{}, currentRow = null, currentBead = null;

  final Set<int> completedRows;

  /// Ряд, над которым работают; `null`, пока не выбран.
  final int? currentRow;

  /// Бусина в [currentRow], после которой остановились; `null` — отмечают целыми рядами.
  final int? currentBead;

  @override
  List<Object?> get props => <Object?>[completedRows.toList()..sort(), currentRow, currentBead];
}
