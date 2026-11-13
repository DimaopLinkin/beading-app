import 'dart:math' as math;

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/settings/floss_brands.dart';
import 'package:beading/domain/stitch/lattice_node.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_layers.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';
import 'package:beading/domain/stitch_import/oxs_pattern.dart';
import 'package:equatable/equatable.dart';

/// Схема вышивки, собранная из файла `.oxs`.
final class OxsConversion extends Equatable {
  const OxsConversion({
    required this.name,
    required this.fabric,
    required this.grid,
    required this.palette,
    required this.layers,
    required this.dropped,
  });

  final String name;
  final Fabric fabric;
  final Grid grid;
  final PaletteSnapshot palette;
  final StitchLayers layers;

  /// Сколько стежков и объектов пришлось пропустить: вне схемы, без цвета или неизвестного вида.
  final int dropped;

  @override
  List<Object?> get props => <Object?>[name, fabric, grid, palette, layers, dropped];
}

/// Переводит [OxsPattern] в модель приложения.
///
/// Соглашения о координатах взяты из спецификации OXS (embroidery-space/xsp-specs): крестики нумеруются с 1,
/// линии решётки — тоже с 1 (угол клетки `(1, 1)` — левый верхний угол схемы), шаг 0,5 — центр клетки.
/// ¾-стежки приводятся к ближайшему виду приложения: угол «четверти» берётся по названию стороны из спецификации.
class OxsConverter {
  const OxsConverter();

  static const Rgb _defaultColor = Rgb(255, 0, 255);
  static const String unknownBrand = 'OXS';

  Result<OxsConversion> convert(OxsPattern pattern) {
    int dropped = 0;

    final List<OxsPaletteItem> materials = pattern.palette.where((i) => i.index > 0).toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    if (materials.length > PaletteSnapshot.maxColors) {
      return const Err<OxsConversion>(ValidationFailure('В палитре файла больше 65 535 цветов'));
    }
    final Map<int, int> value = <int, int>{
      for (final (int i, OxsPaletteItem item) in materials.indexed) item.index: i + 1,
    };

    // Размер: из `properties`, иначе по самому дальнему стежку.
    int width = pattern.width ?? 0;
    int height = pattern.height ?? 0;
    if (width < 1 || height < 1) {
      double maxX = 0;
      double maxY = 0;
      for (final OxsFullStitch s in pattern.fullStitches) {
        maxX = math.max(maxX, s.x);
        maxY = math.max(maxY, s.y);
      }
      for (final OxsPartStitch s in pattern.partStitches) {
        maxX = math.max(maxX, s.x);
        maxY = math.max(maxY, s.y);
      }
      for (final OxsLine l in pattern.lines) {
        maxX = math.max(maxX, math.max(l.x1, l.x2) - 1);
        maxY = math.max(maxY, math.max(l.y1, l.y2) - 1);
      }
      for (final OxsObject o in pattern.objects) {
        maxX = math.max(maxX, o.x);
        maxY = math.max(maxY, o.y);
      }
      if (width < 1) width = math.max(1, maxX.ceil());
      if (height < 1) height = math.max(1, maxY.ceil());
    }
    if (width > Grid.maxSide || height > Grid.maxSide) {
      return const Err<OxsConversion>(ValidationFailure('Схема больше ${Grid.maxSide}×${Grid.maxSide} клеток'));
    }

    final List<int> cells = List<int>.filled(width * height, 0);
    int? valueOf(int palIndex) => value[palIndex];
    bool inside(int col, int row) => col >= 0 && row >= 0 && col < width && row < height;

    for (final OxsFullStitch s in pattern.fullStitches) {
      final int? color = valueOf(s.palIndex);
      final int col = s.x.floor() - 1;
      final int row = s.y.floor() - 1;
      if (color == null || !inside(col, row)) {
        if (s.palIndex != 0) dropped++;
        continue;
      }
      cells[row * width + col] = color;
    }

    final Map<(int, int, PartialKind, StitchOrientation), PartialStitch> partials =
        <(int, int, PartialKind, StitchOrientation), PartialStitch>{};
    void addPartial(int col, int row, PartialKind kind, StitchOrientation orientation, int? color) {
      if (color == null || !inside(col, row)) {
        dropped++;
        return;
      }
      final PartialStitch p = PartialStitch(column: col, row: row, kind: kind, orientation: orientation, color: color);
      partials[p.key] = p;
    }

    for (final OxsPartStitch s in pattern.partStitches) {
      final int col = s.x.floor() - 1;
      final int row = s.y.floor() - 1;
      switch (s.direction) {
        case 3:
          addPartial(col, row, PartialKind.half, StitchOrientation.slash, valueOf(s.palIndex1));
        case 4:
          addPartial(col, row, PartialKind.half, StitchOrientation.backslash, valueOf(s.palIndex1));
        case 1 || 2:
          // Спецификация: левый верх — направление 2 и цвет 1, правый верх — 1 и цвет 2,
          // левый низ — 1 и цвет 1, правый низ — 2 и цвет 2.
          final bool second = s.palIndex1 == 0 && s.palIndex2 != 0;
          final int pal = second ? s.palIndex2 : s.palIndex1;
          final StitchOrientation corner = switch ((s.direction, second)) {
            (2, false) => StitchOrientation.topLeft,
            (1, true) => StitchOrientation.topRight,
            (1, false) => StitchOrientation.bottomLeft,
            _ => StitchOrientation.bottomRight,
          };
          addPartial(col, row, PartialKind.threeQuarter, corner, valueOf(pal));
        default:
          dropped++;
      }
    }

    final Map<(LatticeNode, LatticeNode), LineStitch> lines = <(LatticeNode, LatticeNode), LineStitch>{};
    final Map<LatticeNode, PointStitch> points = <LatticeNode, PointStitch>{};
    final Map<int, OxsPaletteItem> byIndex = <int, OxsPaletteItem>{
      for (final OxsPaletteItem i in materials) i.index: i,
    };

    LatticeNode? node(double x, double y) {
      final int nx = ((x - 1) * 2).round();
      final int ny = ((y - 1) * 2).round();
      if (nx < 0 || ny < 0 || nx > width * 2 || ny > height * 2) return null;
      return LatticeNode(nx, ny);
    }

    for (final OxsLine l in pattern.lines) {
      final int? color = valueOf(l.palIndex);
      final LatticeNode? a = node(l.x1, l.y1);
      final LatticeNode? b = node(l.x2, l.y2);
      if (color == null || a == null || b == null || a == b) {
        dropped++;
        continue;
      }
      final LineKind kind = l.type == 'straightstitch' ? LineKind.straight : LineKind.backstitch;
      final LineStitch line = LineStitch(a: a, b: b, kind: kind, color: color);
      lines[line.key] = line;
    }

    for (final OxsObject o in pattern.objects) {
      final int? color = valueOf(o.palIndex);
      final String type = o.type.toLowerCase();
      if (color == null) {
        dropped++;
        continue;
      }
      if (type == 'knot') {
        final LatticeNode? n = node(o.x, o.y);
        if (n == null) {
          dropped++;
        } else {
          points[n] = PointStitch.knot(node: n, kind: PointKind.frenchKnot, color: color);
        }
      } else if (type == 'bead' || RegExp(r'^bead[\d.]+mm$').hasMatch(type)) {
        final LatticeNode? n = node(o.x, o.y);
        final CatalogRef? ref = n == null ? null : refOf(byIndex[o.palIndex]?.number ?? '');
        if (n == null || ref == null) {
          dropped++;
        } else {
          points[n] = PointStitch.bead(node: n, bead: ref);
        }
      } else if (type == 'quarter') {
        final double fx = o.x - 1;
        final double fy = o.y - 1;
        final int col = fx.floor();
        final int row = fy.floor();
        final bool right = fx - col >= 0.5;
        final bool bottom = fy - row >= 0.5;
        final StitchOrientation corner = switch ((bottom, right)) {
          (false, false) => StitchOrientation.topLeft,
          (false, true) => StitchOrientation.topRight,
          (true, false) => StitchOrientation.bottomLeft,
          (true, true) => StitchOrientation.bottomRight,
        };
        addPartial(col, row, o.petit == false ? PartialKind.quarter : PartialKind.petit, corner, color);
      } else if (type == 'tent') {
        addPartial(
          o.x.floor() - 1,
          o.y.floor() - 1,
          PartialKind.tent,
          o.direction == 1 ? StitchOrientation.backslash : StitchOrientation.slash,
          color,
        );
      } else {
        dropped++;
      }
    }

    // Палитра: символы назначает сама палитра.
    PaletteSnapshot palette = PaletteSnapshot.empty();
    final Map<int, StitchSpec> specs = <int, StitchSpec>{};
    for (final (int i, OxsPaletteItem item) in materials.indexed) {
      final Result<PaletteEdit> added = palette.add(_colorOf(item));
      if (added case Err<PaletteEdit>(:final Failure failure)) {
        return Err<OxsConversion>(failure);
      }
      palette = added.valueOrNull!.palette;
      final int? cross = item.strands;
      final int? back = item.backstitchStrands;
      if (cross != null || back != null) {
        specs[i + 1] = StitchSpec(
          crossStrands: (cross ?? 2).clamp(StitchSpec.minStrands, StitchSpec.maxStrands),
          backstitchStrands: (back ?? 1).clamp(StitchSpec.minStrands, StitchSpec.maxStrands),
        );
      }
    }

    final Fabric fabric = _fabricOf(pattern, pattern.palette.where((i) => i.index == 0).firstOrNull?.color);
    final StitchLayers layers = StitchLayers(
      columns: width,
      rows: height,
      defaultSpec: StitchSpec.forDensity(fabric.stitchesPerInch),
      colorSpecs: specs,
      partials: partials.values,
      lines: lines.values,
      points: points.values,
    );
    final String title = pattern.title.trim();
    return Success<OxsConversion>(
      OxsConversion(
        name: title,
        fabric: fabric,
        grid: Grid.fromCells(width: width, height: height, cells: cells),
        palette: palette,
        layers: layers,
        dropped: dropped,
      ),
    );
  }

  /// `DMC    310`, `DMC 158 [+]` → бренд и номер; без пробела бренд неизвестен.
  static CatalogRef? refOf(String number) {
    final String normalized = number.replaceAll('[+]', '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    final int split = normalized.lastIndexOf(' ');
    if (split < 0) return CatalogRef(brand: unknownBrand, code: normalized);
    final String rawBrand = normalized.substring(0, split);
    final String brand = flossBrandChoices.firstWhere(
      (b) => b.toLowerCase() == rawBrand.toLowerCase(),
      orElse: () => rawBrand,
    );
    return CatalogRef(brand: brand, code: normalized.substring(split + 1));
  }

  PatternColor _colorOf(OxsPaletteItem item) {
    final Rgb rgb = item.color ?? _defaultColor;
    final List<CatalogRef> refs = <CatalogRef>[
      for (final OxsBlendPart b in item.blends.take(PatternColor.maxComponents))
        if (refOf(b.number) case final CatalogRef ref) ref,
    ];
    if (refs.isEmpty) {
      refs.add(refOf(item.number) ?? CatalogRef(brand: unknownBrand, code: '${item.index}'));
    }
    final String name = item.name.trim().isEmpty ? item.number.trim() : item.name.trim();
    return PatternColor(rgb: rgb, name: name.isEmpty ? '${item.index}' : name, components: refs);
  }

  Fabric _fabricOf(OxsPattern pattern, Rgb? clothColor) {
    final Rgb color = clothColor ?? const Rgb(255, 255, 255);
    final double? spi = pattern.stitchesPerInch;
    if (spi != null) {
      final int aida = spi.round();
      if (aida >= Fabric.aidaMinCount && aida <= Fabric.aidaMaxCount) {
        final Result<Fabric> made = Fabric.create(kind: FabricKind.aida, count: aida, color: color);
        if (made case Success<Fabric>(:final Fabric value)) return value;
      }
      final int threads = (spi * 2).round();
      if (threads >= Fabric.threadedMinCount && threads <= Fabric.threadedMaxCount) {
        final Result<Fabric> made = Fabric.create(kind: FabricKind.evenweave, count: threads, color: color);
        if (made case Success<Fabric>(:final Fabric value)) return value;
      }
    }
    return Fabric.standard.withColor(color);
  }
}
