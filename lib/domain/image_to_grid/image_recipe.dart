import 'dart:convert';
import 'dart:typed_data';

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

/// Рецепты схем в файлах приложения: `recipes/<id проекта>.json` и `recipes/<id проекта>.src`.
/// Не синхронизируются между устройствами и не попадают в копию проекта: это только удобство правки.
class ImageRecipeStore {
  const ImageRecipeStore(FileStore files) : _files = files;

  final FileStore _files;

  static String _json(String projectId) => 'recipes/$projectId.json';
  static String _src(String projectId) => 'recipes/$projectId.src';

  Future<Result<void>> save(String projectId, ImageRecipe recipe) async {
    final Result<void> source = await _files.write(_src(projectId), recipe.source);
    if (source case Err<void>()) return source;
    return _files.write(_json(projectId), Uint8List.fromList(utf8.encode(ImageRecipeCodec.encode(recipe))));
  }

  /// Рецепт проекта; `null` — схема создана не в мастере, до T79 или файлы пропали.
  Future<ImageRecipe?> load(String projectId) async {
    final Result<Uint8List> json = await _files.read(_json(projectId));
    final Result<Uint8List> source = await _files.read(_src(projectId));
    if (json.valueOrNull == null || source.valueOrNull == null) return null;
    return ImageRecipeCodec.decode(utf8.decode(json.valueOrNull!), source.valueOrNull!);
  }

  Future<Result<void>> delete(String projectId) async {
    await _files.delete(_json(projectId));
    return _files.delete(_src(projectId));
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
