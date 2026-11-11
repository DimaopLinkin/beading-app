import 'package:beading/domain/catalog/bead_finish_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BeadFinishGroup', () {
    test('группы отделок из T62', () {
      expect(BeadFinishGroup.solid.finishes, <String>{'opaque', 'matte'});
      expect(BeadFinishGroup.luster.finishes, <String>{'luster', 'ceylon', 'galvanized', 'metallic', 'rainbow'});
      expect(BeadFinishGroup.transparent.finishes, <String>{
        'transparent',
        'inside_dyed',
        'silver_lined',
        'gold_lined',
      });
    });

    test('группы не пересекаются', () {
      final List<String> all = <String>[for (final BeadFinishGroup g in BeadFinishGroup.values) ...g.finishes];
      expect(all.toSet(), hasLength(all.length));
    });

    test('finishesOf собирает отделки выбранных групп', () {
      expect(BeadFinishGroup.finishesOf(<BeadFinishGroup>{BeadFinishGroup.solid}), <String>{'opaque', 'matte'});
      expect(BeadFinishGroup.finishesOf(const <BeadFinishGroup>{}), isEmpty);
    });
  });
}
