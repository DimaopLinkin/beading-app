import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/pattern_generation/pattern_template.dart';
import 'package:equatable/equatable.dart';

/// Готовый узор: сетка и палитра. Индекс `n` в сетке — цвет `palette[n - 1]`, `0` — пустая ячейка.
final class GeneratedPattern extends Equatable {
  GeneratedPattern({required this.grid, required List<PatternColor> palette})
    : palette = List<PatternColor>.unmodifiable(palette);

  final Grid grid;
  final List<PatternColor> palette;

  @override
  List<Object?> get props => <Object?>[grid, palette];
}

/// Строит узоры по [PatternTemplate] для выбранной геометрии. Чистая логика, без обращений к хранилищу.
final class PatternGenerator {
  const PatternGenerator();

  /// Узор `width × height` из [colors].
  ///
  /// Шаблон принимает столько цветов, сколько ему нужно (полосы — от двух, остальные — ровно два).
  /// Для [GradientTemplate] цвета — два конца, а промежуточные берутся из [catalog] (ближайшие по ΔE2000);
  /// каталог обязателен. [symmetry] зеркалит первую половину узора на вторую.
  Result<GeneratedPattern> generate({
    required PatternTemplate template,
    required List<PatternColor> colors,
    required int width,
    required int height,
    GridGeometry geometry = const GridGeometry.rectangular(),
    PatternSymmetry symmetry = PatternSymmetry.none,
    List<PatternColor> catalog = const <PatternColor>[],
  }) {
    final String? invalid = _validate(template, colors, width, height, catalog);
    if (invalid != null) return Err<GeneratedPattern>(ValidationFailure(invalid));

    final List<PatternColor> palette = template is GradientTemplate ? _ramp(template, colors, catalog) : colors;
    final List<int> cells = List<int>.filled(width * height, 0);
    for (int row = 0; row < height; row++) {
      for (int column = 0; column < width; column++) {
        final (double x, double y) = _position(geometry, column, row);
        cells[row * width + column] =
            template.colorIndexAt(x, y, width: width, height: height, paletteLength: palette.length) + 1;
      }
    }
    final Grid grid = _mirrored(Grid.fromCells(width: width, height: height, cells: cells), symmetry);
    return Success<GeneratedPattern>(GeneratedPattern(grid: grid, palette: palette));
  }

  /// Раппорт — наименьший повторяющийся фрагмент узора для выбранной геометрии.
  ///
  /// Для шаблонов без повторения (градиент, бордюр) возвращает [ValidationFailure].
  Result<GeneratedPattern> generateRapport({
    required PatternTemplate template,
    required List<PatternColor> colors,
    GridGeometry geometry = const GridGeometry.rectangular(),
  }) {
    final (int, int)? base = template is StripesTemplate ? template.rapportFor(colors.length) : template.rapport;
    if (base == null) return const Err<GeneratedPattern>(ValidationFailure('узор не повторяется, раппорта нет'));
    final (int w, int h) = switch (geometry) {
      RectangularGeometry() => base,
      PeyoteGeometry(:final int drop) => (_lcm(base.$1, 2 * drop), base.$2),
      BrickGeometry() => (base.$1, _lcm(base.$2, 2)),
    };
    return generate(template: template, colors: colors, width: w, height: h, geometry: geometry);
  }

  /// Повторяет раппорт [tile] на сетку `width × height`, начиная с левого верхнего угла.
  static Result<Grid> repeatTile(Grid tile, {required int width, required int height}) {
    if (width < 1 || width > Grid.maxSide || height < 1 || height > Grid.maxSide) {
      return const Err<Grid>(ValidationFailure('размер от 1 до ${Grid.maxSide}'));
    }
    final List<int> cells = <int>[
      for (int row = 0; row < height; row++)
        for (int column = 0; column < width; column++) tile.at(column % tile.width, row % tile.height),
    ];
    return Success<Grid>(Grid.fromCells(width: width, height: height, cells: cells));
  }

  static String? _validate(
    PatternTemplate template,
    List<PatternColor> colors,
    int width,
    int height,
    List<PatternColor> catalog,
  ) {
    if (width < 1 || width > Grid.maxSide || height < 1 || height > Grid.maxSide) {
      return 'размер от 1 до ${Grid.maxSide}';
    }
    final String? parameters = template.parameterError;
    if (parameters != null) return parameters;
    final int? max = template.maxColors;
    if (colors.length < template.minColors || (max != null && colors.length > max)) {
      return 'нужно цветов: ${max == template.minColors ? '${template.minColors}' : 'от ${template.minColors}'}'
          '${max == null || max == template.minColors ? '' : ' до $max'}, дано ${colors.length}';
    }
    if (template is GradientTemplate && catalog.isEmpty) return 'для градиента нужен каталог цветов';
    return null;
  }

  /// Координаты левого верхнего угла ячейки с учётом сдвига геометрии.
  static (double, double) _position(GridGeometry geometry, int column, int row) => switch (geometry) {
    RectangularGeometry() => (column.toDouble(), row.toDouble()),
    PeyoteGeometry(:final int drop) => (column.toDouble(), row + ((column ~/ drop).isOdd ? 0.5 : 0)),
    BrickGeometry() => (column + (row.isOdd ? 0.5 : 0), row.toDouble()),
  };

  /// Ступени градиента: идеальные точки в Lab → ближайшие цвета каталога. Концы — исходные цвета.
  /// Повторы и шаги «назад» по яркости отбрасываются, поэтому L монотонна.
  static List<PatternColor> _ramp(GradientTemplate template, List<PatternColor> ends, List<PatternColor> catalog) {
    final Lab from = Lab.fromRgb(ends.first.rgb);
    final Lab to = Lab.fromRgb(ends.last.rgb);
    final NearestColorMatcher<PatternColor> matcher = NearestColorMatcher<PatternColor>(
      catalog,
      rgbOf: (c) => c.rgb,
    );
    final bool lighter = to.l >= from.l;
    final List<PatternColor> ramp = <PatternColor>[ends.first];
    double lastL = from.l;
    for (int i = 1; i < template.steps - 1; i++) {
      final Lab ideal = Lab.lerp(from, to, i / (template.steps - 1));
      final List<ColorMatch<PatternColor>> match = matcher.nearest(ideal.toRgb(), count: 1);
      if (match.isEmpty) continue;
      final PatternColor color = match.single.item;
      final double l = Lab.fromRgb(color.rgb).l;
      final bool forward = lighter ? l > lastL : l < lastL;
      final bool beforeEnd = lighter ? l < to.l : l > to.l;
      if (forward && beforeEnd && color != ramp.last) {
        ramp.add(color);
        lastL = l;
      }
    }
    if (ends.last != ramp.last) ramp.add(ends.last);
    return ramp;
  }

  static Grid _mirrored(Grid grid, PatternSymmetry symmetry) {
    if (symmetry == PatternSymmetry.none) return grid;
    final bool horizontal = symmetry == PatternSymmetry.horizontal || symmetry == PatternSymmetry.both;
    final bool vertical = symmetry == PatternSymmetry.vertical || symmetry == PatternSymmetry.both;
    final int w = grid.width;
    final int h = grid.height;
    return Grid.fromCells(
      width: w,
      height: h,
      cells: <int>[
        for (int row = 0; row < h; row++)
          for (int column = 0; column < w; column++)
            grid.at(
              horizontal && column >= (w + 1) ~/ 2 ? w - 1 - column : column,
              vertical && row >= (h + 1) ~/ 2 ? h - 1 - row : row,
            ),
      ],
    );
  }

  static int _lcm(int a, int b) {
    int x = a;
    int y = b;
    while (y != 0) {
      final int t = x % y;
      x = y;
      y = t;
    }
    return a ~/ x * b;
  }
}
