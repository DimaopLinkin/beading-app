import 'package:beading/domain/projects/craft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('у бисера пять техник, у вышивки две', () {
    expect(Craft.beading.techniques, <Technique>[
      Technique.loom,
      Technique.peyote,
      Technique.brick,
      Technique.square,
      Technique.offLoom,
    ]);
    expect(Craft.crossStitch.techniques, <Technique>[Technique.crossStitch, Technique.tent]);
  });

  test('техника по умолчанию принадлежит своему ремеслу', () {
    for (final Craft craft in Craft.values) {
      expect(Technique.defaultFor(craft).craft, craft);
    }
  });
}
