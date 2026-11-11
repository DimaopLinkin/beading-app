import 'package:beading/domain/catalog/bead_series.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('серия по бренду: Miyuki — Delica, Toho — круглый, пустой и незнакомый — Delica', () {
    expect(BeadSeries.forBrand('Miyuki'), BeadSeries.delica);
    expect(BeadSeries.forBrand('Toho'), BeadSeries.round);
    expect(BeadSeries.forBrand(''), BeadSeries.delica);
    expect(BeadSeries.forBrand('DMC'), BeadSeries.delica);
  });
}
