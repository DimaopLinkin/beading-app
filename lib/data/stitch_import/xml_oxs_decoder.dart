import 'dart:convert';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/stitch_import/oxs_pattern.dart';
import 'package:xml/xml.dart';

/// Разбор `.oxs` (XML) по спецификации embroidery-space/xsp-specs (MIT). Код сторонних парсеров не используется.
///
/// Недопустимые стежки (нет координат, палитры или номер цвета не число) пропускаются, как велит спецификация;
/// файл без корня `chart` — ошибка.
class XmlOxsDecoder implements OxsDecoder {
  const XmlOxsDecoder();

  /// Предел размера файла: схема на 4096×4096 с миллионами стежков в XML всё равно не нужна.
  static const int maxBytes = 64 * 1024 * 1024;

  @override
  Result<OxsPattern> decode(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      return const Err<OxsPattern>(ValidationFailure('Файл .oxs слишком большой'));
    }
    final XmlDocument document;
    try {
      // Файлы бывают в UTF-8 с меткой BOM и без неё; ошибки кодировки заменяем, а не отвергаем файл.
      document = XmlDocument.parse(utf8.decode(bytes, allowMalformed: true).replaceFirst('\u{FEFF}', ''));
    } on XmlException {
      return const Err<OxsPattern>(ValidationFailure('Файл не похож на .oxs: это не XML'));
    }
    final XmlElement? chart = document.rootElement.name.local == 'chart' ? document.rootElement : null;
    if (chart == null) {
      return const Err<OxsPattern>(ValidationFailure('Файл не похож на .oxs: нет элемента chart'));
    }

    final XmlElement? properties = chart.getElement('properties');
    final List<OxsPaletteItem> palette = <OxsPaletteItem>[];
    final XmlElement? paletteElement = chart.getElement('palette');
    if (paletteElement != null) {
      int position = 0;
      for (final XmlElement item in paletteElement.findElements('palette_item')) {
        final int index = _int(item.getAttribute('index')) ?? position;
        position++;
        palette.add(
          OxsPaletteItem(
            index: index,
            number: (item.getAttribute('number') ?? '').trim(),
            name: (item.getAttribute('name') ?? '').trim(),
            color: _rgb(item.getAttribute('color')),
            strands: _int(item.getAttribute('strands')),
            backstitchStrands: _int(item.getAttribute('bsstrands')),
            blends: <OxsBlendPart>[
              for (final XmlElement b in item.findElements('blend'))
                OxsBlendPart(
                  number: (b.getAttribute('number') ?? '').trim(),
                  name: (b.getAttribute('name') ?? '').trim(),
                  color: _rgb(b.getAttribute('color')),
                ),
            ],
          ),
        );
      }
    }
    final Set<int> known = palette.map((i) => i.index).toSet();

    final List<OxsFullStitch> full = <OxsFullStitch>[];
    for (final XmlElement e in _all(chart, 'fullstitches', 'stitch')) {
      final double? x = _num(e.getAttribute('x'));
      final double? y = _num(e.getAttribute('y'));
      final int? pal = _int(e.getAttribute('palindex'));
      if (x != null && y != null && pal != null && pal != 0 && known.contains(pal)) {
        full.add(OxsFullStitch(x: x, y: y, palIndex: pal));
      }
    }

    final List<OxsPartStitch> parts = <OxsPartStitch>[];
    for (final XmlElement e in _all(chart, 'partstitches', 'partstitch')) {
      final double? x = _num(e.getAttribute('x'));
      final double? y = _num(e.getAttribute('y'));
      final int? direction = _int(e.getAttribute('direction'));
      final int p1 = _int(e.getAttribute('palindex1')) ?? 0;
      final int p2 = _int(e.getAttribute('palindex2')) ?? 0;
      if (x != null && y != null && direction != null && (p1 != 0 || p2 != 0)) {
        parts.add(OxsPartStitch(x: x, y: y, palIndex1: p1, palIndex2: p2, direction: direction));
      }
    }

    final List<OxsLine> lines = <OxsLine>[];
    for (final XmlElement e in _all(chart, 'backstitches', 'backstitch')) {
      final double? x1 = _num(e.getAttribute('x1'));
      final double? y1 = _num(e.getAttribute('y1'));
      final double? x2 = _num(e.getAttribute('x2'));
      final double? y2 = _num(e.getAttribute('y2'));
      final int? pal = _int(e.getAttribute('palindex'));
      if (x1 != null && y1 != null && x2 != null && y2 != null && pal != null && pal != 0 && known.contains(pal)) {
        lines.add(
          OxsLine(
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
            palIndex: pal,
            type: (e.getAttribute('objecttype') ?? 'backstitch').trim().toLowerCase(),
          ),
        );
      }
    }

    final List<OxsObject> objects = <OxsObject>[];
    for (final XmlElement e in _all(chart, 'ornaments_inc_knots_and_beads', 'object')) {
      final double? x = _num(e.getAttribute('x1'));
      final double? y = _num(e.getAttribute('y1'));
      final int? pal = _int(e.getAttribute('palindex'));
      final String type = (e.getAttribute('objecttype') ?? '').trim();
      if (x != null && y != null && pal != null && pal != 0 && known.contains(pal) && type.isNotEmpty) {
        objects.add(
          OxsObject(
            x: x,
            y: y,
            palIndex: pal,
            type: type,
            petit: switch (e.getAttribute('petit')?.trim().toLowerCase()) {
              'true' => true,
              'false' => false,
              _ => null,
            },
            direction: _int(e.getAttribute('direction')),
          ),
        );
      }
    }

    return Success<OxsPattern>(
      OxsPattern(
        title: (properties?.getAttribute('charttitle') ?? '').trim(),
        width: _int(properties?.getAttribute('chartwidth')),
        height: _int(properties?.getAttribute('chartheight')),
        stitchesPerInch: _num(properties?.getAttribute('stitchesperinch')),
        palette: palette,
        fullStitches: full,
        partStitches: parts,
        lines: lines,
        objects: objects,
      ),
    );
  }

  Iterable<XmlElement> _all(XmlElement chart, String section, String item) =>
      chart.findElements(section).expand((s) => s.findElements(item));

  /// Целое; допускает `3.0` и запятую.
  int? _int(String? raw) => _num(raw)?.round();

  /// Число с точкой или запятой; экспонента допустима.
  double? _num(String? raw) {
    if (raw == null) return null;
    final double? v = double.tryParse(raw.trim().replaceAll(',', '.'));
    return v != null && v.isFinite && v.abs() < 1e7 ? v : null;
  }

  Rgb? _rgb(String? raw) {
    final String? value = raw?.trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'nil') return null;
    try {
      return Rgb.fromHex(value);
    } on FormatException {
      return null;
    }
  }
}
