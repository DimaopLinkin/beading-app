import 'dart:io';

import 'package:beading/data/stitch_import/xml_oxs_decoder.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch_import/oxs_converter.dart';
import 'package:beading/domain/stitch_import/oxs_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const OxsConverter converter = OxsConverter();
  OxsConversion sample() => converter
      .convert(const XmlOxsDecoder().decode(File('test/fixtures/oxs/sample.oxs').readAsBytesSync()).valueOrNull!)
      .valueOrNull!;

  test('номер «бренд номер» → ссылка каталога, бренд приводится к названию из настроек', () {
    expect(OxsConverter.refOf('DMC    310'), const CatalogRef(brand: 'DMC', code: '310'));
    expect(OxsConverter.refOf('anchor 47'), const CatalogRef(brand: 'Anchor', code: '47'));
    expect(OxsConverter.refOf('DMC 158 [+]'), const CatalogRef(brand: 'DMC', code: '158'));
    expect(OxsConverter.refOf('Madeira 1001'), const CatalogRef(brand: 'Madeira', code: '1001'));
    expect(OxsConverter.refOf('310'), const CatalogRef(brand: 'OXS', code: '310'));
    expect(OxsConverter.refOf('  '), isNull);
  });

  test('сетка и палитра: крестики с 1, канва не попадает в палитру, символы назначены', () {
    final OxsConversion c = sample();
    expect(c.name, 'Розочка');
    expect((c.grid.width, c.grid.height), (6, 4));
    expect(c.grid.at(0, 0), 1);
    expect(c.grid.at(1, 0), 2);
    expect(c.grid.at(5, 3), 3);
    expect(c.grid.at(2, 2), 0, reason: 'палитра 0 — канва, крестик не создаётся');
    expect(c.palette.length, 3);
    expect(c.palette.colors.every((x) => x.symbol != null), isTrue);
    expect(c.palette.colors[0].components.single, const CatalogRef(brand: 'DMC', code: '310'));
    expect(c.palette.colors[0].name, 'Black');
    expect(c.palette.colors[2].components.map((r) => r.code), <String>['158', '208'], reason: 'смесь из blend');
  });

  test('канва: плотность и цвет', () {
    final Fabric f = sample().fabric;
    expect((f.kind, f.count), (FabricKind.aida, 14));
    expect(f.color.r, 0xF5);
  });

  test('неполные крестики по спецификации', () {
    final List<PartialStitch> p = sample().layers.partials;
    PartialStitch find(int col, int row, PartialKind k) =>
        p.firstWhere((s) => s.column == col && s.row == row && s.kind == k);
    expect(find(2, 0, PartialKind.half).orientation, StitchOrientation.slash);
    expect(find(3, 0, PartialKind.half).orientation, StitchOrientation.backslash);
    expect(find(4, 0, PartialKind.threeQuarter).orientation, StitchOrientation.topRight);
    expect(find(0, 1, PartialKind.threeQuarter).orientation, StitchOrientation.topLeft);
    expect(find(1, 2, PartialKind.quarter).orientation, StitchOrientation.bottomLeft);
    expect(find(4, 2, PartialKind.tent).orientation, StitchOrientation.backslash);
  });

  test('бэкстич: узлы решётки, дубликаты и нулевые отрезки отброшены, straightstitch — прямой стежок', () {
    final List<LineStitch> lines = sample().layers.lines;
    expect(lines.length, 2);
    expect(
      lines.any(
        (l) => l.from == const LatticeNode(0, 0) && l.to == const LatticeNode(2, 0) && l.kind == LineKind.backstitch,
      ),
      isTrue,
    );
    expect(lines.any((l) => l.kind == LineKind.straight && l.to == const LatticeNode(9, 6)), isTrue);
  });

  test('узелок и бусина на узлах решётки; бусина берёт ссылку из палитры', () {
    final List<PointStitch> points = sample().layers.points;
    expect(points.firstWhere((p) => p.kind == PointKind.frenchKnot).node, const LatticeNode(1, 1));
    final PointStitch bead = points.firstWhere((p) => p.kind == PointKind.bead);
    expect(bead.node, const LatticeNode(5, 1));
    expect(bead.bead, const CatalogRef(brand: 'Anchor', code: '47'));
  });

  test('сложения цвета из файла; пропущенное считается', () {
    final OxsConversion c = sample();
    expect(c.layers.specFor(1).crossStrands, 3);
    // крестик (9, 9) вне схемы, объект «3x3» неизвестного вида; стежки с цветом канвы не считаются
    expect(c.dropped, 3, reason: 'крестик вне схемы, объект «3x3» и объект вне схемы');
  });

  test('размер без properties берётся по самому дальнему стежку', () {
    final OxsPattern p = OxsPattern(
      title: '',
      width: null,
      height: null,
      stitchesPerInch: null,
      palette: <OxsPaletteItem>[OxsPaletteItem(index: 1, number: 'DMC 1', name: '', color: null)],
      fullStitches: const <OxsFullStitch>[OxsFullStitch(x: 5, y: 3, palIndex: 1)],
      partStitches: const <OxsPartStitch>[],
      lines: const <OxsLine>[],
      objects: const <OxsObject>[],
    );
    final OxsConversion c = converter.convert(p).valueOrNull!;
    expect((c.grid.width, c.grid.height), (5, 3));
    expect(c.palette.colors.single.rgb.r, 255, reason: 'нет цвета — заметный по умолчанию');
    expect(c.fabric, Fabric.standard);
  });
}
