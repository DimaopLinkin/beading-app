import 'package:equatable/equatable.dart';

/// Особая дата для пасхалок (день рождения, 8 марта, годовщина). Год не нужен: дата повторяется ежегодно.
final class SpecialDate extends Equatable {
  const SpecialDate({required this.label, required this.month, required this.day})
    : assert(month >= 1 && month <= 12, 'month вне 1–12'),
      assert(day >= 1 && day <= 31, 'day вне 1–31');

  /// Название для себя («День рождения»); в тексте комплимента не показывается.
  final String label;
  final int month;
  final int day;

  @override
  List<Object?> get props => <Object?>[label, month, day];
}
