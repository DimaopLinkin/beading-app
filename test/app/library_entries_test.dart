import 'package:beading/app/library_entries.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/library/new_project_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('«Схема из книги» есть в листе «Новый проект» для обоих ремёсел', () {
    final NewProjectRegistry registry = NewProjectRegistry();

    registerLibraryEntries(registry);

    expect(registry.crafts, Craft.values);
    for (final Craft craft in Craft.values) {
      expect(registry.entriesFor(craft), hasLength(1));
    }
  });
}
