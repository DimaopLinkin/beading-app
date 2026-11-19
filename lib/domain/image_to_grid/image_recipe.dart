import 'dart:convert';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/bead_finish_group.dart';
import 'package:beading/domain/catalog/bead_series.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/importance_brush.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_content_cleaner.dart';
import 'package:equatable/equatable.dart';

/// Всё, из чего мастер «Схема из картинки» собрал схему (T79): исходное фото, поворот, рамка, мазки «важного» и
/// параметры. По нему схему можно открыть в мастере и изменить.
final class ImageRecipe extends Equatable {
  const ImageRecipe({
    required this.source,
    required this.quarterTurns,
    required this.crop,
    required this.brush,
    required this.settings,
  });

  /// Фото как выбрано, до поворота и обрезки.
  final Uint8List source;
  final int quarterTurns;
  final CropRect crop;
  final ImageToGridSettings settings;
  final ImportanceBrush brush;

  @override
  List<Object?> get props => <Object?>[source, quarterTurns, crop, brush, settings];
}

/// Запись параметров рецепта в JSON. Имена полей менять нельзя: по ним читаются уже сохранённые рецепты.
abstract final class ImageRecipeCodec {
  static String encode(ImageRecipe recipe) {
    final ImageToGridSettings s = recipe.settings;
    return jsonEncode(<String, Object?>{
      'v': 1,
      'turns': recipe.quarterTurns,
      'crop': <double>[recipe.crop.left, recipe.crop.top, recipe.crop.right, recipe.crop.bottom],
      'brush': <Object?>[
        for (final BrushStroke stroke in recipe.brush.strokes)
          <String, Object?>{'r': stroke.radius, 'p': stroke.points},
      ],
      'settings': <String, Object?>{
        'technique': s.technique.name,
        'bead': CellMetricsCodec.encode(s.beadSize).valueOrNull,
        'fabric': CellMetricsCodec.encode(s.fabric).valueOrNull,
        'columns': s.columns,
        // Высота и подгонка (T88a): пишутся, только когда высота задана; старые записи без них читаются как раньше.
        if (s.rows != null) 'rows': s.rows,
        if (s.rows != null) 'fit': s.fit.name,
        'maxColors': s.maxColors,
        'paletteSource': s.paletteSource.name,
        'series': s.beadSeries?.name,
        'finish': <String>[for (final BeadFinishGroup g in s.finishGroups) g.name],
        'dither': s.dither,
        'voting': s.detailVoting,
        'masks': s.useMasks,
        'preset': s.preset?.name,
        'background': s.background.name,
        'outline': s.outline,
        'backstitch': s.backstitch,
        'blends': s.blends,
        'otherBrands': s.otherBrands,
        'otherBrandsOnly': s.otherBrandsOnly.toList()..sort(),
        'shadows': s.shadows,
        'stash': s.onlyStash,
        'mixed': s.mixedStitches,
      },
    });
  }

  /// Читает рецепт; `null`, если запись повреждена.
  static ImageRecipe? decode(String json, Uint8List source) {
    try {
      final Map<String, Object?> map = jsonDecode(json) as Map<String, Object?>;
      final Map<String, Object?> s = map['settings']! as Map<String, Object?>;
      final List<Object?> crop = map['crop']! as List<Object?>;
      const ImageToGridSettings base = ImageToGridSettings();
      final Result<CellMetrics> bead = CellMetricsCodec.decode(s['bead']! as String);
      final Result<CellMetrics> fabric = CellMetricsCodec.decode(s['fabric']! as String);
      final Set<BeadFinishGroup> finish = <BeadFinishGroup>{
        for (final Object? name in s['finish']! as List<Object?>)
          ...BeadFinishGroup.values.where((g) => g.name == name),
      };
      final String? preset = s['preset'] as String?;
      final String? series = s['series'] as String?;
      final ImageToGridSettings settings = base.copyWith(
        technique: Technique.values.byName(s['technique']! as String),
        beadSize: bead.valueOrNull! as BeadSize,
        fabric: fabric.valueOrNull! as Fabric,
        columns: s['columns']! as int,
        rows: s['rows'] as int?,
        clearRows: s['rows'] == null,
        fit: FrameFit.values.asNameMap()[s['fit']] ?? FrameFit.crop,
        maxColors: s['maxColors']! as int,
        paletteSource: PaletteSource.values.byName(s['paletteSource']! as String),
        beadSeries: series == null ? null : BeadSeries.values.byName(series),
        finishGroups: finish,
        dither: s['dither']! as bool,
        detailVoting: s['voting']! as bool,
        useMasks: s['masks']! as bool,
        preset: preset == null ? null : GenerationPreset.values.byName(preset),
        clearPreset: preset == null,
        background: BackgroundMode.values.byName(s['background']! as String),
        outline: s['outline']! as bool,
        backstitch: s['backstitch']! as bool,
        blends: s['blends']! as bool,
        otherBrands: (s['otherBrands'] as bool?) ?? false,
        otherBrandsOnly: <String>{...?(s['otherBrandsOnly'] as List<Object?>?)?.cast<String>()},
        shadows: s['shadows'] as int?,
        clearShadows: s['shadows'] == null,
        onlyStash: (s['stash'] as bool?) ?? false,
        mixedStitches: (s['mixed'] as bool?) ?? false,
      );
      return ImageRecipe(
        source: source,
        quarterTurns: map['turns']! as int,
        crop: CropRect(
          left: (crop[0]! as num).toDouble(),
          top: (crop[1]! as num).toDouble(),
          right: (crop[2]! as num).toDouble(),
          bottom: (crop[3]! as num).toDouble(),
        ),
        brush: ImportanceBrush(<BrushStroke>[
          for (final Object? stroke in map['brush']! as List<Object?>)
            BrushStroke(
              radius: ((stroke! as Map<String, Object?>)['r']! as num).toDouble(),
              points: <double>[
                for (final Object? p in (stroke as Map<String, Object?>)['p']! as List<Object?>) (p! as num).toDouble(),
              ],
            ),
        ]),
        settings: settings,
      );
    } on Object {
      return null;
    }
  }
}

/// Параметры рецептов в базе (T96): строка на проект, синхронизируется между устройствами вместе с фото.
abstract interface class ImageRecipeIndex {
  /// JSON параметров ([ImageRecipeCodec]) живого рецепта; `null`, если его нет.
  Future<String?> params(String projectId);

  /// Записывает или оживляет рецепт; [sourcePath] — относительный путь фото в [FileStore].
  Future<void> put(String projectId, {required String params, required String sourcePath});

  /// Надгробие рецепта; отсутствующий рецепт — не ошибка.
  Future<void> remove(String projectId);

  /// Живые проекты со схемой-сеткой, у которых рецепта в базе нет (кандидаты на перенос старых файлов).
  Future<List<String>> projectsWithoutRecipe();
}

/// Рецепты схем: фото файлом `recipes/<id проекта>.src`, параметры строкой в [ImageRecipeIndex].
/// До T96 параметры лежали файлом `recipes/<id проекта>.json` и не синхронизировались; такие рецепты
/// переносятся в базу при чтении и в [adoptLegacy]. Без индекса (тесты) параметры по-прежнему пишутся файлом.
/// В копию проекта рецепт не попадает: это только удобство правки.
class ImageRecipeStore {
  const ImageRecipeStore(FileStore files, {ImageRecipeIndex? index}) : _files = files, _index = index;

  final FileStore _files;
  final ImageRecipeIndex? _index;

  static String _json(String projectId) => 'recipes/$projectId.json';

  /// Путь фото рецепта. Одинаков на всех устройствах: по нему файл кладёт синхронизация.
  static String sourcePath(String projectId) => 'recipes/$projectId.src';

  Future<Result<void>> save(String projectId, ImageRecipe recipe) async {
    final Result<void> source = await _files.write(sourcePath(projectId), recipe.source);
    if (source case Err<void>()) return source;
    final String params = ImageRecipeCodec.encode(recipe);
    final ImageRecipeIndex? index = _index;
    if (index == null) {
      return _files.write(_json(projectId), Uint8List.fromList(utf8.encode(params)));
    }
    return _guard(() => index.put(projectId, params: params, sourcePath: sourcePath(projectId)));
  }

  /// Рецепт проекта; `null` — схема создана не в мастере, до T79, фото не доехало или файлы пропали.
  Future<ImageRecipe?> load(String projectId) async {
    final Uint8List? source = (await _files.read(sourcePath(projectId))).valueOrNull;
    if (source == null) return null;
    String? params;
    try {
      params = await _index?.params(projectId);
    } on Object {
      params = null;
    }
    params ??= await _legacy(projectId);
    return params == null ? null : ImageRecipeCodec.decode(params, source);
  }

  Future<Result<void>> delete(String projectId) async {
    final ImageRecipeIndex? index = _index;
    if (index != null) {
      final Result<void> removed = await _guard(() => index.remove(projectId));
      if (removed case Err<void>()) return removed;
    }
    await _files.delete(_json(projectId));
    return _files.delete(sourcePath(projectId));
  }

  /// Переносит в базу рецепты, записанные до T96 только файлами, чтобы они уехали на другие устройства.
  Future<void> adoptLegacy() async {
    final ImageRecipeIndex? index = _index;
    if (index == null) return;
    try {
      for (final String id in await index.projectsWithoutRecipe()) {
        await _legacy(id);
      }
    } on Object {
      // Перенос повторится при следующем запуске.
    }
  }

  /// Параметры из старого файла; при наличии индекса и фото переносит их в базу.
  Future<String?> _legacy(String projectId) async {
    final Uint8List? json = (await _files.read(_json(projectId))).valueOrNull;
    if (json == null) return null;
    final String params = utf8.decode(json, allowMalformed: true);
    final ImageRecipeIndex? index = _index;
    if (index != null && (await _files.read(sourcePath(projectId))).valueOrNull != null) {
      final Result<void> put = await _guard(
        () => index.put(projectId, params: params, sourcePath: sourcePath(projectId)),
      );
      if (put case Success<void>()) await _files.delete(_json(projectId));
    }
    return params;
  }

  static Future<Result<void>> _guard(Future<void> Function() action) async {
    try {
      await action();
      return const Success<void>(null);
    } on Object catch (error) {
      return Err<void>(StorageFailure('Рецепт не записан: $error'));
    }
  }
}

/// Убирает рецепт вместе с удалённым проектом.
class ImageRecipeContentCleaner implements ProjectContentCleaner {
  const ImageRecipeContentCleaner(ImageRecipeStore recipes) : _recipes = recipes;

  final ImageRecipeStore _recipes;

  @override
  bool supports(ContentKind kind) => kind == ContentKind.grid;

  @override
  Future<Result<void>> remove(Project project) => _recipes.delete(project.id);
}
