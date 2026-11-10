import 'package:beading/presentation/grid_pattern/bead_finish.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('отделка из каталога сводится к подсказке', () {
    expect(BeadFinish.parse('luster'), BeadFinish.glossy);
    expect(BeadFinish.parse('inside_dyed'), BeadFinish.glossy);
    expect(BeadFinish.parse('matte'), BeadFinish.matte);
    expect(BeadFinish.parse('matte_metallic'), BeadFinish.matte);
    expect(BeadFinish.parse('galvanized'), BeadFinish.metallic);
    expect(BeadFinish.parse('transparent'), BeadFinish.transparent);
    expect(BeadFinish.parse(null), BeadFinish.glossy);
  });
}
