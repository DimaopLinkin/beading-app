/// Раздаёт цветам схемы знаки для режима символов.
///
/// Порядок набора: A–Z, цифры, затем знаки, геометрические фигуры и греческие буквы. Набор не меняется между
/// версиями: уже выданные символы остаются теми же, новый цвет получает первый свободный.
final class SymbolAssigner {
  const SymbolAssigner();

  /// Весь набор, не меньше 120 разных одиночных символов. Без мелких и похожих друг на друга знаков (см. [avoided]).
  List<String> get symbols => _symbols;

  /// Знаки, которые раньше входили в набор, а теперь исключены: мелкие (`: ; - * ^ ~ ! /`, точки, запятые) и похожие
  /// на другие (`I`, `O`, `Q` рядом с `1`, `0`). У старых схем они ещё могут быть записаны в палитре.
  static const Set<String> avoided = <String>{
    'I',
    'O',
    'Q',
    '-',
    '*',
    '/',
    '=',
    '~',
    '^',
    '!',
    ':',
    ';',
    '.',
    ',',
    '·',
    '♪',
    '♭',
    '♯',
    '¤',
    '¢',
    '∞',
    '≈',
    '≠',
    '±', //
    '☺', '✓', '÷', '×', '‡',
  };

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
        'ABCDEFGHJKLMNPRSTUVWXYZ', // 23: без I, O, Q
        '0123456789', // 10
        r'+#%&@?<>$', // знаки
        '■□▲△▼▽◆◇○●★☆♠♣♥♦✚✖✿❖▣▤▥▦▧▨▩◢◣◤◥◐◑◉◈⬟⬢⬣⬥✱✜✤✥✸❂❋⌘⚑☘☾♛', // фигуры
        'ΣΩΨΦΔΛΠΘΞΓαβγδλμπσφψω', // греческие
        '☀☂♀♂✦✧§¶†£¥€', // разное
      ]
      .expand((group) => group.runes.map(String.fromCharCode))
      .where((s) => !SymbolAssigner.avoided.contains(s))
      .toSet()
      .toList(),
);
