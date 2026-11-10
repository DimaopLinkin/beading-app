/// Материал позиции каталога: бисер сейчас, мулине добавит T36 ([ADR-0003]).
enum CatalogMaterial {
  bead,
  floss
  ;

  /// Значение в JSON и в колонке `material`.
  String get wire => name;

  static CatalogMaterial? fromWire(String value) {
    for (final CatalogMaterial material in values) {
      if (material.wire == value) {
        return material;
      }
    }
    return null;
  }
}
