/// Как рисовать отделку бусины: подсказка в схеме, а не точная копия.
enum BeadFinish {
  /// Обычная глянцевая (люстр, Ceylon, окрашенная внутри): небольшой блик.
  glossy,

  /// Матовая: без блика.
  matte,

  /// Металлик и гальваника: градиент.
  metallic,

  /// Прозрачная: светлый центр и контур.
  transparent
  ;

  /// По строке отделки из каталога (`luster`, `matte`, `metallic`, `transparent`…); неизвестное — [glossy].
  static BeadFinish parse(String? finish) {
    final String value = finish?.toLowerCase() ?? '';
    if (value.contains('mat')) return BeadFinish.matte;
    if (value.contains('metal') || value.contains('galvan') || value.contains('palladium')) {
      return BeadFinish.metallic;
    }
    if (value.contains('transp') || value.contains('crystal') || value.contains('clear')) return BeadFinish.transparent;
    return BeadFinish.glossy;
  }
}
