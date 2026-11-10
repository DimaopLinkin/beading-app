/// Ключ для поиска по артикулу: «DB-0010», «db10» и «DB 10» дают `db10`; «10» остаётся `10`.
String codeSearchKey(String value) {
  final String lower = value.toLowerCase().replaceAll(RegExp('[^a-z0-9а-яё]'), '');
  // Ведущие нули внутри числовых групп не значимы: 0010 == 10.
  return lower.replaceAllMapped(RegExp(r'\d+'), (m) {
    final String stripped = m[0]!.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    return stripped;
  });
}

/// Ключ без буквенной приставки: `db10` → `10`, чтобы «10» находил `DB0010`.
String numericPart(String key) => key.replaceFirst(RegExp('^[a-zа-яё]+'), '');
