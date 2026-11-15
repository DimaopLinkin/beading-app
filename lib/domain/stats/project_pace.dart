import 'package:equatable/equatable.dart';

/// Темп работы над проектом и оценка остатка. Считается по клеткам (крестикам, бусинам), а не по рядам: длина рядов
/// у пейота и кирпичного стежка разная. Это оценка: темп бывает разным.
final class ProjectPace extends Equatable {
  const ProjectPace({required this.perHour, required this.remaining});

  /// Минимум времени работы, раньше которого темпу верить рано.
  static const Duration minWorked = Duration(hours: 2);

  /// Клеток в час.
  final double perHour;

  /// Сколько работы осталось при таком темпе.
  final Duration remaining;

  /// `null`, если оценивать рано (мало времени, ничего не сделано) или уже всё сделано.
  static ProjectPace? estimate({required int done, required int total, required Duration worked}) {
    if (worked < minWorked || done <= 0 || done >= total) {
      return null;
    }
    final double hours = worked.inMicroseconds / Duration.microsecondsPerHour;
    final double perHour = done / hours;
    final int remainingMicros = ((total - done) / perHour * Duration.microsecondsPerHour).round();
    return ProjectPace(
      perHour: perHour,
      remaining: Duration(microseconds: remainingMicros),
    );
  }

  @override
  List<Object?> get props => <Object?>[perHour, remaining];
}
