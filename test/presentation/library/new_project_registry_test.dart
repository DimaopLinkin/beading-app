import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

NewProjectEntry entry(String id, Craft craft, {int order = 100}) => NewProjectEntry(
  id: id,
  craft: craft,
  order: order,
  title: (_) => id,
  icon: CupertinoIcons.add,
  onSelected: (_) async {},
);

void main() {
  test('пункты выбираются по ремеслу и идут по порядку order', () {
    final NewProjectRegistry registry = NewProjectRegistry()
      ..register(entry('draw', Craft.beading, order: 20))
      ..register(entry('book', Craft.beading, order: 10))
      ..register(entry('stitch', Craft.crossStitch));

    expect(registry.entriesFor(Craft.beading).map((e) => e.id), <String>['book', 'draw']);
    expect(registry.entriesFor(Craft.crossStitch).map((e) => e.id), <String>['stitch']);
  });

  test('crafts перечисляет только ремёсла, у которых есть пункты', () {
    final NewProjectRegistry registry = NewProjectRegistry()..register(entry('stitch', Craft.crossStitch));

    expect(registry.crafts, <Craft>[Craft.crossStitch]);
  });

  test('повторная регистрация того же id заменяет пункт', () {
    final NewProjectRegistry registry = NewProjectRegistry()
      ..register(entry('book', Craft.beading, order: 5))
      ..register(entry('book', Craft.beading, order: 7));

    expect(registry.entriesFor(Craft.beading).single.order, 7);
  });

  test('пустой реестр: ремёсл и пунктов нет', () {
    final NewProjectRegistry registry = NewProjectRegistry();

    expect(registry.crafts, isEmpty);
    expect(registry.entriesFor(Craft.beading), isEmpty);
  });
}
