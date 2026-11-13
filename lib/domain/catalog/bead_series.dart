/// Серия бисера, из которой собирается палитра схемы (T62): Delica и круглый Toho не смешиваются, потому что по размеру
/// и форме их бусины в одном полотне лежат неровно.
enum BeadSeries {
  /// Miyuki Delica: цилиндрический бисер.
  delica('Miyuki', 'Delica'),

  /// Круглый бисер, сейчас Toho Round.
  round('Toho', 'Round')
  ;

  const BeadSeries(this.brand, this.catalogSeries);

  /// Бренд серии в каталоге (`CatalogColor.brand`).
  final String brand;

  /// Название серии в каталоге (`CatalogColor.series`).
  final String catalogSeries;

  /// Серия по бренду из настройки: пустой или незнакомый бренд — Delica.
  static BeadSeries forBrand(String brand) {
    for (final BeadSeries series in values) {
      if (series.brand == brand) return series;
    }
    return delica;
  }
}
