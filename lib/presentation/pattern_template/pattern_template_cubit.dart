import 'dart:math' as math;

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/pattern_generation/pattern_generator.dart';
import 'package:beading/domain/settings/setting_key.dart';
import 'package:beading/domain/settings/settings_repository.dart';
import 'package:beading/presentation/pattern_template/pattern_template_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Экран «Узор по шаблону»: галерея шаблонов, параметры, живой предпросмотр, сохранение в новый проект.
class PatternTemplateCubit extends Cubit<PatternTemplateState> {
  PatternTemplateCubit({
    required CatalogRepository catalog,
    required SettingsRepository settings,
    required CreateGridPattern createPattern,
    SettingKey<String>? brandSetting,
    PatternGenerator generator = const PatternGenerator(),
  }) : _catalog = catalog,
       _settings = settings,
       _create = createPattern,
       _brandSetting = brandSetting,
       _generator = generator,
       super(const PatternTemplateState());

  /// Размер образца карточки галереи, ячеек.
  static const int sampleSide = 12;

  /// Цвета, с которых начинается узор: насыщенный синий и тёплый светлый. Берутся ближайшие из каталога.
  static final List<Rgb> _starterTargets = <Rgb>[Rgb.fromHex('#1F3A8A'), Rgb.fromHex('#F5E9C8')];

  final CatalogRepository _catalog;
  final SettingsRepository _settings;
  final CreateGridPattern _create;
  final SettingKey<String>? _brandSetting;
  final PatternGenerator _generator;

  /// Загружает каталог бисера, выбирает стартовые цвета и считает первый узор.
  Future<void> start() async {
    emit(state.copyWith(status: TemplateStatus.loading, clearProblem: true));
    final Result<List<CatalogColor>> found = await _catalog.search(material: CatalogMaterial.bead);
    if (isClosed) return;
    final List<CatalogColor> all = found.valueOrNull ?? const <CatalogColor>[];
    if (all.length < 2) {
      emit(state.copyWith(status: TemplateStatus.failure, problem: TemplateProblem.catalogUnavailable));
      return;
    }
    final SettingKey<String>? key = _brandSetting;
    final String preferred = key == null ? '' : ((await _settings.read(key)).valueOrNull ?? '');
    if (isClosed) return;
    final List<CatalogColor> ofBrand = all.where((c) => c.brand == preferred).toList(growable: false);
    final List<PatternColor> catalog = <PatternColor>[
      for (final CatalogColor c in ofBrand.length >= 2 ? ofBrand : all) _toPatternColor(c),
    ];
    final NearestColorMatcher<PatternColor> matcher = NearestColorMatcher<PatternColor>(catalog, rgbOf: (c) => c.rgb);
    final List<PatternColor> colors = <PatternColor>[];
    for (final Rgb target in _starterTargets) {
      final PatternColor? pick = matcher
          .nearest(target, count: catalog.length)
          .map((m) => m.item)
          .where((c) => !colors.contains(c))
          .firstOrNull;
      if (pick != null) colors.add(pick);
    }
    emit(state.copyWith(status: TemplateStatus.ready, catalog: catalog, colors: colors));
    _refresh(gallery: true);
  }

  /// Цвет каталога как цвет схемы: ссылка на позицию и отделка.
  static PatternColor _toPatternColor(CatalogColor c) =>
      PatternColor(rgb: c.rgb, name: c.name, components: [c.ref], finish: c.finish);

  void selectKind(TemplateKind kind) => setParams(state.params.copyWith(kind: kind));

  /// Меняет параметры; размеры и числа шаблона приводятся к допустимым границам.
  void setParams(TemplateParams params) {
    final TemplateParams next = _clamped(params);
    final bool galleryChanged = next.technique != state.params.technique;
    emit(state.copyWith(params: next, clearProblem: true));
    _refresh(gallery: galleryChanged);
  }

  /// Заменяет цвет [index]; «живой предпросмотр» и галерея пересчитываются.
  void setColor(int index, PatternColor color) {
    if (index < 0 || index >= state.colors.length) return;
    emit(state.copyWith(colors: <PatternColor>[...state.colors]..[index] = color, clearProblem: true));
    _refresh(gallery: true);
  }

  void addColor(PatternColor color) {
    if (!state.canAddColor) return;
    emit(state.copyWith(colors: <PatternColor>[...state.colors, color], clearProblem: true));
    _refresh(gallery: true);
  }

  void removeColor(int index) {
    if (!state.canRemoveColor || index < 0 || index >= state.colors.length) return;
    emit(state.copyWith(colors: <PatternColor>[...state.colors]..removeAt(index), clearProblem: true));
    _refresh(gallery: true);
  }

  void setName(String name) => emit(state.copyWith(name: name));

  /// Сохраняет текущий предпросмотр новым проектом. [fallbackName] — название, если поле пустое.
  Future<void> save({required String fallbackName}) async {
    if (state.saving || state.projectId != null) return;
    final GeneratedPatternView? view = _viewForSave();
    if (view == null) {
      emit(state.copyWith(problem: TemplateProblem.invalidParameters));
      return;
    }
    emit(state.copyWith(saving: true, clearProblem: true));
    final String name = state.name.trim().isEmpty ? fallbackName : state.name.trim();
    final TemplateParams p = state.params;
    final Result<CreatedGridPattern> created = await _create(
      name: name,
      technique: p.technique,
      metrics: p.bead,
      width: view.pattern.grid.width,
      height: view.pattern.grid.height,
      geometry: p.geometry,
      grid: view.pattern.grid,
      palette: view.palette,
    );
    if (isClosed) return;
    switch (created) {
      case Success<CreatedGridPattern>(:final CreatedGridPattern value):
        emit(state.copyWith(saving: false, projectId: value.project.id));
      case Err<CreatedGridPattern>(:final Failure failure):
        emit(
          state.copyWith(
            saving: false,
            problem: failure is ValidationFailure ? TemplateProblem.invalidParameters : TemplateProblem.saveFailed,
          ),
        );
    }
  }

  GeneratedPatternView? _viewForSave() {
    final GeneratedPattern? pattern = state.preview;
    if (pattern == null) return null;
    PaletteSnapshot palette = PaletteSnapshot.empty();
    for (final PatternColor color in pattern.palette) {
      final Result<PaletteEdit> added = palette.add(color);
      if (added is Err<PaletteEdit>) return null;
      palette = added.valueOrNull!.palette;
    }
    return GeneratedPatternView(pattern, palette);
  }

  TemplateParams _clamped(TemplateParams p) => p.copyWith(
    width: p.width.clamp(TemplateParams.minSide, TemplateParams.maxWidth),
    height: p.height.clamp(TemplateParams.minSide, TemplateParams.maxHeight),
    stripeWidth: p.stripeWidth.clamp(1, TemplateParams.maxStripeWidth),
    amplitude: p.amplitude.clamp(1, 12),
    zigzagThickness: p.zigzagThickness.clamp(1, 6),
    gap: p.gap.clamp(0, 8),
    diamondSize: p.diamondSize.clamp(1, 12),
    cellSize: p.cellSize.clamp(1, 12),
    steps: p.steps.clamp(2, 24),
    borderThickness: p.borderThickness.clamp(1, math.max(1, math.min(p.width, p.height) ~/ 2)),
  );

  /// Пересчитывает предпросмотр; с [gallery] — и образцы галереи (когда меняются цвета или техника).
  void _refresh({bool gallery = false}) {
    if (state.status != TemplateStatus.ready) return;
    final TemplateParams p = state.params;
    final Result<GeneratedPattern> result = _build(p, p.width, p.height);
    final Map<TemplateKind, GeneratedPattern> samples = gallery
        ? <TemplateKind, GeneratedPattern>{
            for (final TemplateKind kind in TemplateKind.values)
              if (_build(TemplateParams(kind: kind, technique: p.technique), sampleSide, sampleSide)
                  case Success<GeneratedPattern>(:final GeneratedPattern value))
                kind: value,
          }
        : state.gallery;
    switch (result) {
      case Success<GeneratedPattern>(:final GeneratedPattern value):
        emit(state.copyWith(preview: value, gallery: samples, clearProblem: true));
      case Err<GeneratedPattern>():
        emit(state.copyWith(gallery: samples, clearPreview: true, problem: TemplateProblem.invalidParameters));
    }
  }

  Result<GeneratedPattern> _build(TemplateParams p, int width, int height) => _generator.generate(
    template: p.template,
    colors: state.colors.take(p.kind == TemplateKind.stripes ? state.colors.length : 2).toList(growable: false),
    width: width,
    height: height,
    geometry: p.geometry,
    symmetry: p.symmetry,
    catalog: state.catalog,
  );
}

/// Узор и его палитра со знаками, готовые к записи.
class GeneratedPatternView {
  const GeneratedPatternView(this.pattern, this.palette);

  final GeneratedPattern pattern;
  final PaletteSnapshot palette;
}
