import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/data/stitch_import/xml_oxs_decoder.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch_import/oxs_pattern.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const XmlOxsDecoder decoder = XmlOxsDecoder();
  final Uint8List sample = File('test/fixtures/oxs/sample.oxs').readAsBytesSync();

  test('разбирает свойства, палитру, стежки, линии и объекты', () {
    final OxsPattern p = decoder.decode(sample).valueOrNull!;
    expect(p.title, 'Розочка');
    expect((p.width, p.height, p.stitchesPerInch), (6, 4, 14.0));
    expect(p.palette.map((i) => i.index), <int>[0, 1, 2, 3]);
    expect(p.palette[0].color, const Rgb(0xF5, 0xF0, 0xE1));
    expect(p.palette[1].number, 'DMC    310');
    expect((p.palette[1].strands, p.palette[1].backstitchStrands), (3, 1));
    expect(p.palette[3].blends.map((b) => b.number), <String>['DMC 158', 'DMC 208']);
    // Крестик на цвете канвы (палитра 0) и с неизвестным номером палитры отброшены не декодером, а в одном случае:
    // 0 — по спецификации не хранится; 9 в фикстуре — это координата, а не номер.
    expect(p.fullStitches.length, 4);
    expect(p.partStitches.length, 4);
    expect(p.lines.length, 4);
    expect(p.objects.length, 5);
    expect(p.objects.first.type, 'knot');
    expect(p.objects[2].petit, isFalse);
    expect(p.objects.last.direction, 1);
  });

  test('запятая как десятичный разделитель, nil вместо цвета, BOM', () {
    const String xml =
        '<chart><properties stitchesperinch="14,5"/><palette><palette_item index="1" number="DMC 1" color="nil"/></palette> '
        '<fullstitches><stitch x="1,0" y="2" palindex="1"/></fullstitches></chart>';
    final OxsPattern p = decoder.decode(Uint8List.fromList(<int>[0xEF, 0xBB, 0xBF, ...utf8.encode(xml)])).valueOrNull!;
    expect(p.stitchesPerInch, 14.5);
    expect(p.palette.single.color, isNull);
    expect(p.fullStitches.single.x, 1.0);
  });

  test('стежки с битыми координатами или чужим номером палитры пропускаются', () {
    const String xml =
        '<chart><palette><palette_item index="1" number="DMC 1" color="000000"/></palette><fullstitches> '
        '<stitch x="a" y="1" palindex="1"/><stitch x="1" y="1" palindex="7"/><stitch y="1" palindex="1"/> '
        '<stitch x="1" y="1" palindex="1"/></fullstitches></chart>';
    expect(decoder.decode(Uint8List.fromList(utf8.encode(xml))).valueOrNull!.fullStitches.length, 1);
  });

  test('не XML и не chart — понятная ошибка', () {
    expect(decoder.decode(Uint8List.fromList(utf8.encode('мусор'))).failureOrNull, isA<ValidationFailure>());
    expect(decoder.decode(Uint8List.fromList(utf8.encode('<other/>'))).failureOrNull, isA<ValidationFailure>());
  });
}
