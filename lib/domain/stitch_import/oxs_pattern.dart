import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:equatable/equatable.dart';

/// Часть смеси в цвете палитры OXS (элемент `blend`).
final class OxsBlendPart extends Equatable {
  const OxsBlendPart({required this.number, required this.name, required this.color});

  final String number;
  final String name;
  final Rgb? color;

  @override
  List<Object?> get props => <Object?>[number, name, color];
}

/// Цвет палитры OXS (`palette_item`). Элемент с индексом 0 — цвет канвы.
final class OxsPaletteItem extends Equatable {
  OxsPaletteItem({
    required this.index,
    required this.number,
    required this.name,
    required this.color,
    this.strands,
    this.backstitchStrands,
    List<OxsBlendPart> blends = const <OxsBlendPart>[],
  }) : blends = List<OxsBlendPart>.unmodifiable(blends);

  final int index;

  /// Бренд и номер как в файле (`DMC 310`); у канвы — `cloth`.
  final String number;
  final String name;

  /// Цвет на экране; `null`, если в файле пусто или `nil`.
  final Rgb? color;
  final int? strands;
  final int? backstitchStrands;
  final List<OxsBlendPart> blends;

  @override
  List<Object?> get props => <Object?>[index, number, name, color, strands, backstitchStrands, blends];
}

/// Полный крестик (`stitch`); координаты с 1.
final class OxsFullStitch extends Equatable {
  const OxsFullStitch({required this.x, required this.y, required this.palIndex});

  final double x;
  final double y;
  final int palIndex;

  @override
  List<Object?> get props => <Object?>[x, y, palIndex];
}

/// Неполный крестик (`partstitch`).
final class OxsPartStitch extends Equatable {
  const OxsPartStitch({
    required this.x,
    required this.y,
    required this.palIndex1,
    required this.palIndex2,
    required this.direction,
  });

  final double x;
  final double y;
  final int palIndex1;
  final int palIndex2;
  final int direction;

  @override
  List<Object?> get props => <Object?>[x, y, palIndex1, palIndex2, direction];
}

/// Бэкстич и родственные линии (`backstitch`); координаты — линии решётки с 1, шаг 0,5.
final class OxsLine extends Equatable {
  const OxsLine({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.palIndex,
    required this.type,
  });

  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final int palIndex;
  final String type;

  @override
  List<Object?> get props => <Object?>[x1, y1, x2, y2, palIndex, type];
}

/// Узелок, бусина, четверть и прочее (`object`).
final class OxsObject extends Equatable {
  const OxsObject({
    required this.x,
    required this.y,
    required this.palIndex,
    required this.type,
    this.petit,
    this.direction,
  });

  final double x;
  final double y;
  final int palIndex;
  final String type;
  final bool? petit;
  final int? direction;

  @override
  List<Object?> get props => <Object?>[x, y, palIndex, type, petit, direction];
}

/// Разобранный файл `.oxs`, без привязки к модели приложения.
final class OxsPattern extends Equatable {
  OxsPattern({
    required this.title,
    required this.width,
    required this.height,
    required this.stitchesPerInch,
    required List<OxsPaletteItem> palette,
    required List<OxsFullStitch> fullStitches,
    required List<OxsPartStitch> partStitches,
    required List<OxsLine> lines,
    required List<OxsObject> objects,
  }) : palette = List<OxsPaletteItem>.unmodifiable(palette),
       fullStitches = List<OxsFullStitch>.unmodifiable(fullStitches),
       partStitches = List<OxsPartStitch>.unmodifiable(partStitches),
       lines = List<OxsLine>.unmodifiable(lines),
       objects = List<OxsObject>.unmodifiable(objects);

  final String title;

  /// Размер из `properties`; `null`, если не указан.
  final int? width;
  final int? height;
  final double? stitchesPerInch;
  final List<OxsPaletteItem> palette;
  final List<OxsFullStitch> fullStitches;
  final List<OxsPartStitch> partStitches;
  final List<OxsLine> lines;
  final List<OxsObject> objects;

  @override
  List<Object?> get props => <Object?>[
    title,
    width,
    height,
    stitchesPerInch,
    palette,
    fullStitches,
    partStitches,
    lines,
    objects,
  ];
}

/// Разбирает байты `.oxs`. Реализация — в слое data.
abstract interface class OxsDecoder {
  Result<OxsPattern> decode(Uint8List bytes);
}
