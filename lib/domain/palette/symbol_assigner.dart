/// Раздаёт цветам схемы знаки для режима символов.
///
/// Порядок набора: A–Z, цифры, затем знаки, геометрические фигуры и греческие буквы. Набор не меняется между
/// версиями: уже выданные символы остаются теми же, новый цвет получает первый свободный.
final class SymbolAssigner {
  const SymbolAssigner();

  /// Весь набор, не меньше 120 разных одиночных символов.
  List<String> get symbols => _symbols;

  /// Первый свободный символ из набора или `null`, если все заняты. [used] может содержать `null`.
  String? next(Iterable<String?> used) {
    final Set<String> taken = used.whereType<String>().toSet();
    for (final String s in _symbols) {
      if (!taken.contains(s)) {
        return s;
      }
    }
    return null;
  }
}

final List<String> _symbols = List<String>.unmodifiable(
  <String>[
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ', // 26
    '0123456789', // 10
    r'+-*/=#%&@?!<>~^$:;', // знаки
    '■□▲△▼▽◆◇○●★☆♠♣♥♦♪✚✖✿❖▣▤▥▦▧▨▩◢◣◤◥◐◑', // фигуры
    'ΣΩΨΦΔΛΠΘΞΓαβγδλμπσφψω', // греческие
    '☀☂☺♀♂✓✦✧♯♭§¶†‡¤¢£¥€∞≈≠±×÷', // разное
  ].expand((group) => group.runes.map(String.fromCharCode)).toSet().toList(),
);
