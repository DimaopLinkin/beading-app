import 'package:beading/app/library_entries.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('«Схема из книги», «Нарисовать» и «Схема из картинки» есть в листе «Новый проект»', () {
    final NewProjectRegistry registry = NewProjectRegistry();

    registerLibraryEntries(registry);

    expect(registry.crafts, Craft.values);
    for (final Craft craft in Craft.values) {
      expect(registry.entriesFor(craft).any((e) => e.id.startsWith('import-book')), isTrue);
    }
    // «Нарисовать схему» — только бисер: редактор вышивки делает T40.
    expect(registry.entriesFor(Craft.beading).any((e) => e.id == 'draw-grid-beading'), isTrue);
    expect(registry.entriesFor(Craft.crossStitch), hasLength(1));
    expect(registry.entriesFor(Craft.beading).any((e) => e.id == 'image-to-grid-beading'), isTrue);
  });

  test('«Узор по шаблону» есть только у бисера: цвета и геометрия пока бисерные', () {
    final NewProjectRegistry registry = NewProjectRegistry();

    registerLibraryEntries(registry);

    expect(registry.entriesFor(Craft.beading).map((e) => e.id), contains('pattern-template'));
    expect(registry.entriesFor(Craft.crossStitch).map((e) => e.id), isNot(contains('pattern-template')));
  });
}
