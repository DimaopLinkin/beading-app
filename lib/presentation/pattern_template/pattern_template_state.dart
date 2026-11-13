import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/pattern_generation/pattern_generator.dart';
import 'package:beading/domain/pattern_generation/pattern_template.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:equatable/equatable.dart';

/// Шаблон в галерее.
enum TemplateKind { stripes, zigzag, diamonds, checker, gradient, border }

/// Что пошло не так, в терминах для текста на экране.
enum TemplateProblem {
  /// Каталог цветов не загрузился.
  catalogUnavailable,

  /// Параметры не дали узора (слишком большой размер, мало цветов).
  invalidParameters,
  saveFailed,
}

enum TemplateStatus { loading, ready, failure }

/// Параметры узора: что выбрано в галерее и на панели настроек. У каждого шаблона свои числа; чужие не используются.
class TemplateParams extends Equatable {
  const TemplateParams({
    this.kind = TemplateKind.stripes,
    this.technique = Technique.loom,
    this.bead = BeadSize.delica11,
    this.width = 12,
    this.height = 40,
    this.symmetry = PatternSymmetry.none,
    this.axis = PatternAxis.y,
    this.stripeWidth = 2,
    this.amplitude = 3,
    this.zigzagThickness = 1,
    this.gap = 2,
    this.diamondSize = 3,
    this.cellSize = 2,
    this.steps = 8,
    this.borderThickness = 2,
  });

  /// Ограничения полей ввода на экране: браслет и подвеска, не гобелен.
  static const int minSide = 2;
  static const int maxWidth = 100;
  static const int maxHeight = 400;
  static const int maxStripeWidth = 12;

  final TemplateKind kind;
  final Technique technique;
  final BeadSize bead;
  final int width;
  final int height;
  final PatternSymmetry symmetry;
  final PatternAxis axis;
  final int stripeWidth;
  final int amplitude;
  final int zigzagThickness;
  final int gap;
  final int diamondSize;
  final int cellSize;
  final int steps;
  final int borderThickness;

  /// Шаблон для генератора по выбранному виду и числам.
  PatternTemplate get template => switch (kind) {
    TemplateKind.stripes => StripesTemplate(stripeWidth: stripeWidth, axis: axis),
    TemplateKind.zigzag => ZigzagTemplate(amplitude: amplitude, thickness: zigzagThickness, gap: gap),
    TemplateKind.diamonds => DiamondsTemplate(size: diamondSize),
    TemplateKind.checker => CheckerTemplate(cellSize: cellSize),
    TemplateKind.gradient => GradientTemplate(steps: steps, axis: axis),
    TemplateKind.border => BorderTemplate(thickness: borderThickness),
  };

  /// Форма сетки для техники: мозаика и кирпичный стежок сдвигают ячейки, остальные ровные.
  GridGeometry get geometry => switch (technique) {
    Technique.peyote => const GridGeometry.peyote(),
    Technique.brick => const GridGeometry.brick(),
    _ => const GridGeometry.rectangular(),
  };

  /// Сдвинутая геометрия: зеркало по индексам в ней приблизительное.
  bool get isShifted => technique == Technique.peyote || technique == Technique.brick;

  TemplateParams copyWith({
    TemplateKind? kind,
    Technique? technique,
    BeadSize? bead,
    int? width,
    int? height,
    PatternSymmetry? symmetry,
    PatternAxis? axis,
    int? stripeWidth,
    int? amplitude,
    int? zigzagThickness,
    int? gap,
    int? diamondSize,
    int? cellSize,
    int? steps,
    int? borderThickness,
  }) => TemplateParams(
    kind: kind ?? this.kind,
    technique: technique ?? this.technique,
    bead: bead ?? this.bead,
    width: width ?? this.width,
    height: height ?? this.height,
    symmetry: symmetry ?? this.symmetry,
    axis: axis ?? this.axis,
    stripeWidth: stripeWidth ?? this.stripeWidth,
    amplitude: amplitude ?? this.amplitude,
    zigzagThickness: zigzagThickness ?? this.zigzagThickness,
    gap: gap ?? this.gap,
    diamondSize: diamondSize ?? this.diamondSize,
    cellSize: cellSize ?? this.cellSize,
    steps: steps ?? this.steps,
    borderThickness: borderThickness ?? this.borderThickness,
  );

  @override
  List<Object?> get props => <Object?>[
    kind,
    technique,
    bead,
    width,
    height,
    symmetry,
    axis,
    stripeWidth,
    amplitude,
    zigzagThickness,
    gap,
    diamondSize,
    cellSize,
    steps,
    borderThickness,
  ];
}

class PatternTemplateState extends Equatable {
  const PatternTemplateState({
    this.status = TemplateStatus.loading,
    this.params = const TemplateParams(),
    this.colors = const <PatternColor>[],
    this.catalog = const <PatternColor>[],
    this.preview,
    this.gallery = const <TemplateKind, GeneratedPattern>{},
    this.name = '',
    this.problem,
    this.saving = false,
    this.projectId,
  });

  /// Сколько цветов можно задать в полосах.
  static const int maxStripeColors = 6;

  final TemplateStatus status;
  final TemplateParams params;

  /// Выбранные цвета. Градиенту нужны первый и последний из первых двух, полосам — все, остальным — два первых.
  final List<PatternColor> colors;

  /// Цвета каталога для подбора и для промежуточных ступеней градиента.
  final List<PatternColor> catalog;

  /// Узор по текущим параметрам; `null`, пока не посчитан или параметры не годятся.
  final GeneratedPattern? preview;

  /// Маленькие образцы всех шаблонов на текущих цветах: превью карточек галереи.
  final Map<TemplateKind, GeneratedPattern> gallery;
  final String name;
  final TemplateProblem? problem;
  final bool saving;

  /// Созданный проект после сохранения.
  final String? projectId;

  /// Сколько цветов используется текущим шаблоном.
  int get usedColors => params.kind == TemplateKind.stripes ? colors.length : 2;

  bool get canAddColor => params.kind == TemplateKind.stripes && colors.length < maxStripeColors;

  bool get canRemoveColor => params.kind == TemplateKind.stripes && colors.length > 2;

  PatternTemplateState copyWith({
    TemplateStatus? status,
    TemplateParams? params,
    List<PatternColor>? colors,
    List<PatternColor>? catalog,
    GeneratedPattern? preview,
    Map<TemplateKind, GeneratedPattern>? gallery,
    String? name,
    TemplateProblem? problem,
    bool? saving,
    String? projectId,
    bool clearPreview = false,
    bool clearProblem = false,
  }) => PatternTemplateState(
    status: status ?? this.status,
    params: params ?? this.params,
    colors: colors ?? this.colors,
    catalog: catalog ?? this.catalog,
    preview: clearPreview ? null : (preview ?? this.preview),
    gallery: gallery ?? this.gallery,
    name: name ?? this.name,
    problem: clearProblem ? null : (problem ?? this.problem),
    saving: saving ?? this.saving,
    projectId: projectId ?? this.projectId,
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    params,
    colors,
    catalog,
    preview,
    gallery,
    name,
    problem,
    saving,
    projectId,
  ];
}
