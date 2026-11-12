import 'dart:typed_data';

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/load_project_preview.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_grid_pattern.dart';
import '../../support/fake_image_pattern.dart';

Project _project(String id, {Craft craft = Craft.beading, ContentKind kind = ContentKind.grid, String? cover}) =>
    Project(
      id: id,
      name: id,
      status: ProjectStatus.inProgress,
      craft: craft,
      technique: Technique.defaultFor(craft),
      contentKind: kind,
      notes: '',
      coverPath: cover,
      lastWorkedAt: DateTime.utc(2026),
    );

void main() {
  late FakeGridPatternRepository patterns;
  late FakeGridProgressStore rows;
  late FakeCellProgressStore cells;
  late FakeFileStore files;
  late LoadProjectPreview load;

  setUp(() {
    patterns = FakeGridPatternRepository();
    rows = FakeGridProgressStore();
    cells = FakeCellProgressStore();
    files = FakeFileStore();
    load = LoadProjectPreview(patterns: patterns, rows: rows, cells: cells, files: files);
  });

  test('бисер: доля — отмеченные ряды от всех рядов', () async {
    patterns.byProject['p'] = sampleGridPattern(projectId: 'p');
    rows.rows.add(0);
    final ProjectPreview preview = await load(_project('p'));
    expect(preview.pattern, isNotNull);
    expect(preview.progress, closeTo(1 / 4, 1e-9), reason: 'у пейота со сдвигом 4 ряда плетения');
    expect(preview.percent, 25);
  });

  test('вышивка: доля — сделанные клетки от клеток с цветом', () async {
    patterns.byProject['p'] = sampleGridPattern(projectId: 'p');
    await cells.setCells('pat-1', const <CellPosition>[CellPosition(0, 0), CellPosition(1, 0)], done: true);
    final ProjectPreview preview = await load(_project('p', craft: Craft.crossStitch));
    expect(preview.progress, closeTo(2 / 9, 1e-9), reason: '9 клеток с цветом, 3 пустые');
    expect(preview.percent, 22);
  });

  test('схема без отметок — 0 %', () async {
    patterns.byProject['p'] = sampleGridPattern(projectId: 'p');
    expect((await load(_project('p'))).percent, 0);
  });

  test('почти готово не округляется до 100, а крошечное не до 0', () {
    expect(const ProjectPreview(progress: 0.996).percent, 99);
    expect(const ProjectPreview(progress: 0.001).percent, 1);
    expect(const ProjectPreview(progress: 1).percent, 100);
    expect(const ProjectPreview().percent, isNull);
  });

  test('схема из книги: картинка первой страницы, процента нет', () async {
    files.files['img/1.png'] = Uint8List.fromList(<int>[1, 2, 3]);
    final ProjectPreview preview = await load(_project('b', kind: ContentKind.image, cover: 'img/1.png'));
    expect(preview.cover, isNotNull);
    expect(preview.percent, isNull);
  });

  test('нет схемы или файла — пустое превью, без падения', () async {
    expect(await load(_project('none')), const ProjectPreview());
    expect((await load(_project('b', kind: ContentKind.image, cover: 'нет.png'))).cover, isNull);
  });
}
