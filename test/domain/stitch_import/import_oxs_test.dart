import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beading/data/stitch_import/xml_oxs_decoder.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/use_cases/create_project.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';
import 'package:beading/domain/stitch_import/import_oxs.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';
import '../../support/fake_grid_pattern.dart';
import '../../support/fake_project_repository.dart';

Uint8List _bytes(String xml) => Uint8List.fromList(utf8.encode(xml));

void main() {
  late FakeProjectRepository projects;
  late FakeGridPatternRepository patterns;
  late ImportOxs useCase;

  setUp(() {
    projects = FakeProjectRepository();
    patterns = FakeGridPatternRepository();
    final FakeIdGenerator ids = FakeIdGenerator();
    useCase = ImportOxs(
      decoder: const XmlOxsDecoder(),
      createPattern: CreateGridPattern(
        createProject: CreateProject(repository: projects, ids: ids, clock: FakeClock(DateTime.utc(2026))),
        projects: projects,
        patterns: patterns,
        ids: ids,
      ),
    );
  });

  test('создаёт проект-вышивку со схемой, палитрой, канвой и слоями', () async {
    final ImportResult result = (await useCase(
      File('test/fixtures/oxs/sample.oxs').readAsBytesSync(),
      fileName: 'rose.oxs',
    )).valueOrNull!;
    expect(result.importedIds.length, 1);
    final GridPattern saved = patterns.byProject[result.importedIds.single]!;
    expect(saved.grid.width, 6);
    expect(saved.palette.length, 3);
    final StitchLayers layers = StitchLayersCodec.fromBlob(saved.layers!).valueOrNull!;
    expect(layers.lines.length, 2);
    final Project project = (await projects.get(result.importedIds.single)).valueOrNull!;
    expect((project.name, project.craft, project.contentKind), ('Розочка', Craft.crossStitch, ContentKind.grid));
  });

  test('без названия в файле — имя файла без расширения', () async {
    const String xml = '<chart><properties chartwidth="2" chartheight="2"/><palette/></chart>';
    final ImportResult result = (await useCase(
      _bytes(xml),
      fileName: 'Мой цветок.OXS',
    )).valueOrNull!;
    expect((await projects.get(result.importedIds.single)).valueOrNull!.name, 'Мой цветок');
    expect(patterns.byProject[result.importedIds.single]!.layers, isNull);
  });

  test('не .oxs — ошибка, проект не создаётся', () async {
    expect((await useCase(_bytes('не xml'), fileName: 'x.oxs')).isFailure, isTrue);
    expect(projects.projects, isEmpty);
  });
}
