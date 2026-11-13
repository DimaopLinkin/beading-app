import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/stitch/line_stitch.dart';
import 'package:beading/domain/stitch/partial_stitch.dart';
import 'package:beading/domain/stitch/point_stitch.dart';
import 'package:beading/domain/stitch/stitch_spec.dart';
import 'package:equatable/equatable.dart';

/// Слои вышивки поверх [Grid]: неполные крестики, линии (бэкстич, прямые стежки), узелки и бисер.
///
/// Разреженные и отдельные от сетки: у бисерных схем пустые. Размер [columns]×[rows] совпадает с сеткой схемы.
/// Цвета — значения сетки (`palette[color - 1]`). Каждый слой — отдельный список, так что бэкстич можно показать,
/// скрыть, сохранить или сгенерировать (контуры из картинки, T49) независимо от крестиков.
///
/// Записи хранятся в каноническом порядке без дублей: повторный ключ — ошибка конструктора ([ArgumentError]).
final class StitchLayers extends Equatable {
  factory StitchLayers({
    required int columns,
    required int rows,
    StitchSpec defaultSpec = const StitchSpec(),
    Map<int, StitchSpec> colorSpecs = const <int, StitchSpec>{},
    Iterable<PartialStitch> partials = const <PartialStitch>[],
    Iterable<LineStitch> lines = const <LineStitch>[],
    Iterable<PointStitch> points = const <PointStitch>[],
  }) {
    if (columns < 1 || columns > Grid.maxSide) throw ArgumentError.value(columns, 'columns', 'от 1 до ${Grid.maxSide}');
    if (rows < 1 || rows > Grid.maxSide) throw ArgumentError.value(rows, 'rows', 'от 1 до ${Grid.maxSide}');
    final List<PartialStitch> sortedPartials = partials.toList()..sort();
    for (int i = 0; i < sortedPartials.length; i++) {
      final PartialStitch p = sortedPartials[i];
      if (p.column >= columns || p.row >= rows) throw ArgumentError('неполный крестик ${p.cell} вне схемы');
      if (i > 0 && sortedPartials[i - 1].key == p.key) throw ArgumentError('повтор неполного крестика в ${p.cell}');
    }
    final List<LineStitch> sortedLines = lines.toList()..sort();
    for (int i = 0; i < sortedLines.length; i++) {
      final LineStitch l = sortedLines[i];
      if (l.to.x > columns * 2 || l.to.y > rows * 2 || l.from.x > columns * 2) {
        throw ArgumentError('линия ${l.from}–${l.to} вне схемы');
      }
      if (i > 0 && sortedLines[i - 1].key == l.key) throw ArgumentError('повтор линии ${l.from}–${l.to}');
    }
    final List<PointStitch> sortedPoints = points.toList()..sort();
    for (int i = 0; i < sortedPoints.length; i++) {
      final PointStitch p = sortedPoints[i];
      if (p.node.x > columns * 2 || p.node.y > rows * 2) throw ArgumentError('точка ${p.node} вне схемы');
      if (i > 0 && sortedPoints[i - 1].node == p.node) throw ArgumentError('две точки в ${p.node}');
    }
    for (final int color in colorSpecs.keys) {
      if (color < 1 || color > 0xFFFF) throw ArgumentError.value(color, 'colorSpecs', 'цвет от 1 до 65535');
    }
    return StitchLayers._(
      columns,
      rows,
      defaultSpec,
      Map<int, StitchSpec>.unmodifiable(colorSpecs),
      List<PartialStitch>.unmodifiable(sortedPartials),
      List<LineStitch>.unmodifiable(sortedLines),
      List<PointStitch>.unmodifiable(sortedPoints),
    );
  }

  /// Пустые слои для схемы такого размера.
  factory StitchLayers.empty({required int columns, required int rows}) => StitchLayers(columns: columns, rows: rows);

  const StitchLayers._(
    this.columns,
    this.rows,
    this.defaultSpec,
    this.colorSpecs,
    this.partials,
    this.lines,
    this.points,
  );

  final int columns;
  final int rows;

  /// Сложения по умолчанию.
  final StitchSpec defaultSpec;

  /// Переопределения сложений по цвету (значение сетки).
  final Map<int, StitchSpec> colorSpecs;

  /// В порядке рядов, столбцов, вида.
  final List<PartialStitch> partials;

  /// Бэкстич и прямые стежки, по возрастанию начала.
  final List<LineStitch> lines;

  /// Узелки и бусины, по рядам узлов.
  final List<PointStitch> points;

  /// Нет ни одной записи (настройки сложений не считаются).
  bool get isEmpty => partials.isEmpty && lines.isEmpty && points.isEmpty;

  /// Сложения для цвета: своё или по умолчанию.
  StitchSpec specFor(int color) => colorSpecs[color] ?? defaultSpec;

  /// Цвета палитры, которые используют слои (узелки и линии, неполные крестики); бусины без цвета не считаются.
  Set<int> get usedColors => <int>{
    for (final PartialStitch p in partials) p.color,
    for (final LineStitch l in lines) l.color,
    for (final PointStitch p in points)
      if (p.kind != PointKind.bead) p.color,
  };

  /// Копия с другими записями; проверки те же, что у конструктора.
  StitchLayers rebuilt({
    int? columns,
    int? rows,
    StitchSpec? defaultSpec,
    Map<int, StitchSpec>? colorSpecs,
    Iterable<PartialStitch>? partials,
    Iterable<LineStitch>? lines,
    Iterable<PointStitch>? points,
  }) => StitchLayers(
    columns: columns ?? this.columns,
    rows: rows ?? this.rows,
    defaultSpec: defaultSpec ?? this.defaultSpec,
    colorSpecs: colorSpecs ?? this.colorSpecs,
    partials: partials ?? this.partials,
    lines: lines ?? this.lines,
    points: points ?? this.points,
  );

  @override
  List<Object?> get props => <Object?>[columns, rows, defaultSpec, colorSpecs, partials, lines, points];
}
