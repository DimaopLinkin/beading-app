import 'package:equatable/equatable.dart';

/// Формат листа для печати схемы.
enum PrintPaper {
  a4(210, 297, 10),
  a3(297, 420, 10),
  a2(420, 594, 7)
  ;

  const PrintPaper(this.widthMm, this.heightMm, this.pixelsPerMm);

  final int widthMm;
  final int heightMm;

  /// Плотность растра: у A2 пониже, чтобы страница не весила сотни мегабайт (клетка 21 px).
  final int pixelsPerMm;
}

/// Настройки печати: формат листов схемы и сколько мест на одной стойке для игл с нитками (T80).
///
/// Номера в легенде идут по цветам схемы; если цветов больше, чем мест на стойке, нумерация продолжается на следующей
/// стойке: «2-7» — вторая стойка, седьмое место.
final class PrintOptions extends Equatable {
  const PrintOptions({this.paper = PrintPaper.a4, this.slotsPerRack = defaultSlots});

  static const int defaultSlots = 50;
  static const int minSlots = 10;
  static const int maxSlots = 200;

  final PrintPaper paper;
  final int slotsPerRack;

  PrintOptions copyWith({PrintPaper? paper, int? slotsPerRack}) =>
      PrintOptions(paper: paper ?? this.paper, slotsPerRack: slotsPerRack ?? this.slotsPerRack);

  /// Номер места для цвета с индексом [index] (с нуля) среди [total] цветов.
  String slotLabel(int index, int total) =>
      total <= slotsPerRack ? '${index + 1}' : '${index ~/ slotsPerRack + 1}-${index % slotsPerRack + 1}';

  /// Для хранения в настройках: `a4:50`.
  String encode() => '${paper.name}:$slotsPerRack';

  /// Неверная или пустая строка даёт значения по умолчанию.
  factory PrintOptions.decode(String? value) {
    final List<String> parts = (value ?? '').split(':');
    if (parts.length != 2) return const PrintOptions();
    final PrintPaper paper = PrintPaper.values.firstWhere((p) => p.name == parts[0], orElse: () => PrintPaper.a4);
    final int? slots = int.tryParse(parts[1]);
    return PrintOptions(
      paper: paper,
      slotsPerRack: slots == null ? defaultSlots : slots.clamp(minSlots, maxSlots),
    );
  }

  @override
  List<Object?> get props => <Object?>[paper, slotsPerRack];
}
