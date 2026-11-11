import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Color;

import 'package:beading/data/catalog/catalog_file_parser.dart';
import 'package:beading/data/image_to_grid/ui_image_decoder.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_file.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/mm.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/cell_regions.dart';
import 'package:beading/domain/image_to_grid/cell_sampler.dart';
import 'package:beading/domain/image_to_grid/face_guide.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/generation_stats.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_prefilter.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_constraint.dart';
import 'package:beading/domain/image_to_grid/palette_from_generated.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/image_to_grid/work_image.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/realistic_cells.dart';

/// Галерея качества генератора (T51): фото-фикстуры × виды схем × варианты конвейера.
///
/// Листы «до / после» и таблица метрик строятся командой `flutter test --tags gallery test/gallery/`
/// (см. `test/gallery/README.md`), а регрессионный тест `quality_gallery_test.dart` сверяет метрики
/// с `test/fixtures/photos/baseline.json`.

/// Папка с фикстурами и базой метрик.
const String photosDir = 'test/fixtures/photos';

/// Файл базы метрик.
const String baselinePath = '$photosDir/baseline.json';

/// Расширения картинок в папке личных фото.
const Set<String> _imageExtensions = <String>{'.png', '.jpg', '.jpeg', '.heic', '.webp'};

/// Фото галереи.
final class GalleryPhoto {
  const GalleryPhoto(this.name, this.image);

  final String name;
  final SourceImage image;
}

/// Вид схемы: что и в какой технике строим.
final class GalleryTarget {
  const GalleryTarget({
    required this.id,
    required this.technique,
    required this.metrics,
    required this.columns,
    required this.maxColors,
    this.large = false,
  });

  final String id;
  final Technique technique;
  final CellMetrics metrics;
  final int columns;
  final int maxColors;

  /// Второй, крупный размер (T65): только со свободной палитрой и только под тегом `gallery`, в базу метрик не входит.
  final bool large;

  bool get isBeads => technique.craft == Craft.beading;
  GridGeometry get geometry => ImageToGridSettings(technique: technique).geometry;
}

/// Квадратная клетка канвы 1 × 1 мм: у вышивки пока нет своей модели ткани (T36).
final class _StitchCell implements CellMetrics {
  const _StitchCell();

  @override
  double get widthMm => 1;

  @override
  double get heightMm => 1;
}

/// Виды схем галереи: бисер на станке и в пейоте, вышивка крестиком.
const List<GalleryTarget> galleryTargets = <GalleryTarget>[
  GalleryTarget(id: 'loom', technique: Technique.loom, metrics: BeadSize.delica11, columns: 40, maxColors: 10),
  GalleryTarget(id: 'peyote', technique: Technique.peyote, metrics: BeadSize.delica11, columns: 40, maxColors: 10),
  GalleryTarget(id: 'stitch', technique: Technique.crossStitch, metrics: _StitchCell(), columns: 60, maxColors: 16),
];

/// Крупный размер (T65): станок 100 столбцов и 20 цветов, вышивка 150 и 30, как их видит Настя на готовой работе.
const List<GalleryTarget> galleryLargeTargets = <GalleryTarget>[
  GalleryTarget(
    id: 'loom-l',
    technique: Technique.loom,
    metrics: BeadSize.delica11,
    columns: 100,
    maxColors: 20,
    large: true,
  ),
  GalleryTarget(
    id: 'stitch-l',
    technique: Technique.crossStitch,
    metrics: _StitchCell(),
    columns: 150,
    maxColors: 30,
    large: true,
  ),
];

/// Вариант конвейера. Новая стадия генератора добавляет сюда свой вариант: листы и метрики «до / после» получаются сами.
final class GalleryVariant {
  const GalleryVariant({
    required this.id,
    required this.title,
    required this.build,
    this.beadsOnly = false,
    this.catalog = false,
  });

  final String id;
  final String title;

  /// Берёт цвета из каталога бисера: на крупном размере (свободная палитра) не строится.
  final bool catalog;

  /// Только для бисера: нужен каталог бисера.
  final bool beadsOnly;

  final ImageToGridRequest Function(SourceImage image, GalleryTarget target, List<CatalogColor> catalog) build;

  bool appliesTo(GalleryTarget target) => (!beadsOnly || target.isBeads) && !(catalog && target.large);
}

ImageToGridRequest _request(
  SourceImage image,
  GalleryTarget target,
  List<CatalogColor> catalog, {
  bool dither = false,
  bool useCatalog = false,
  ImagePrefilter? prefilter,
  bool pixelStages = false,
  GenerationPreset? preset,
  ImageMaskSet? masks,
}) {
  final ImageToGridSettings settings = ImageToGridSettings(
    technique: target.technique,
    beadSize: target.metrics is BeadSize ? target.metrics as BeadSize : BeadSize.delica11,
    columns: target.columns,
    maxColors: target.maxColors,
    paletteSource: useCatalog ? PaletteSource.catalog : PaletteSource.free,
    dither: dither,
    preset: preset,
  );
  final ImageToGridRequest request = settings.toRequest(
    image: image,
    catalog: useCatalog ? catalog : const <CatalogColor>[],
    masks: masks,
  );
  final PaletteBuilder? paletteBuilder = pixelStages ? const AccentPaletteBuilder() : null;
  final CellLabeler? labeler = pixelStages ? const VotingCellLabeler() : null;
  if (target.metrics is BeadSize) {
    if (preset != null || (prefilter == null && !pixelStages)) return request;
    return ImageToGridRequest(
      image: image,
      geometry: request.geometry,
      metrics: request.metrics,
      columns: request.columns,
      rows: request.rows,
      maxColors: request.maxColors,
      constraint: request.constraint,
      dither: dither,
      prefilter: prefilter,
      paletteBuilder: paletteBuilder,
      labeler: labeler,
    );
  }
  // Для вышивки размер ячейки свой: пересобираем запрос с квадратной клеткой.
  return ImageToGridRequest(
    image: image,
    geometry: request.geometry,
    metrics: target.metrics,
    columns: target.columns,
    rows: GridSizing.rowsForColumns(
      imageWidth: image.width,
      imageHeight: image.height,
      geometry: request.geometry,
      metrics: target.metrics,
      columns: target.columns,
    ),
    maxColors: target.maxColors,
    dither: dither,
    prefilter: prefilter ?? request.prefilter,
    paletteBuilder: paletteBuilder ?? request.paletteBuilder,
    labeler: labeler ?? request.labeler,
    smoother: request.smoother,
    refillFreedColors: request.refillFreedColors,
    faces: request.faces,
    steps: request.steps,
    suggestBlends: target.technique.craft == Craft.crossStitch,
  );
}

/// Лица фикстур, размеченные вручную (на Linux нет Apple Vision): ключ — картинка, загруженная [loadPhotos].
final Expando<ImageMaskSet> galleryFaces = Expando<ImageMaskSet>('galleryFaces');

/// Рамка и ориентиры лица на `portrait.png` (320 × 320), размечены по снимку вручную.
ImageMaskSet _portraitFaces() {
  const double side = 320;
  NormalizedPoint p(double x, double y) => NormalizedPoint(x / side, y / side);
  List<NormalizedPoint> ring(double cx, double cy, double rx, double ry) => <NormalizedPoint>[
    p(cx - rx, cy),
    p(cx, cy - ry),
    p(cx + rx, cy),
    p(cx, cy + ry),
  ];
  return ImageMaskSet(
    width: 320,
    height: 320,
    faces: <DetectedFace>[
      DetectedFace(
        bounds: const NormalizedRect(left: 112 / side, top: 46 / side, right: 169 / side, bottom: 114 / side),
        landmarks: FaceLandmarks(
          leftEye: ring(126, 66, 6, 3),
          rightEye: ring(154, 66, 7, 3.5),
          leftPupil: <NormalizedPoint>[p(126.5, 66.5)],
          rightPupil: <NormalizedPoint>[p(154, 66)],
          leftEyebrow: <NormalizedPoint>[p(120, 58), p(132, 57)],
          rightEyebrow: <NormalizedPoint>[p(148, 57), p(160, 59)],
          nose: <NormalizedPoint>[p(134, 80), p(140, 83), p(145, 80)],
          outerLips: ring(139.5, 90, 13, 5),
          innerLips: <NormalizedPoint>[p(130, 89.5), p(149, 89.5)],
        ),
      ),
    ],
  );
}

/// Варианты галереи.
final List<GalleryVariant> galleryVariants = <GalleryVariant>[
  const GalleryVariant(
    id: 't24',
    title: 'T24 (как сейчас)',
    build: _request,
  ),
  GalleryVariant(
    id: 't24-dither',
    title: 'T24 + дизеринг',
    build: (image, target, catalog) => _request(image, target, catalog, dither: true),
  ),
  GalleryVariant(
    id: 't24-catalog',
    title: 'T24 + каталог Toho/Delica',
    beadsOnly: true,
    catalog: true,
    build: (image, target, catalog) => _request(image, target, catalog, useCatalog: true),
  ),
  GalleryVariant(
    id: 't52-prefilter',
    title: 'T52: подготовка фото',
    build: (image, target, catalog) => _request(image, target, catalog, prefilter: const EdgePreservingPrefilter()),
  ),
  GalleryVariant(
    id: 't53-pixels',
    title: 'T53: палитра с акцентами + голосование',
    build: (image, target, catalog) => _request(
      image,
      target,
      catalog,
      prefilter: const EdgePreservingPrefilter(),
      pixelStages: true,
    ),
  ),
  GalleryVariant(
    id: 't53-catalog',
    title: 'T53 + каталог Toho/Delica',
    beadsOnly: true,
    catalog: true,
    build: (image, target, catalog) => _request(
      image,
      target,
      catalog,
      useCatalog: true,
      prefilter: const EdgePreservingPrefilter(),
      pixelStages: true,
    ),
  ),
  GalleryVariant(
    id: 't47-simpler',
    title: 'T47: проще',
    build: (image, target, catalog) => _request(image, target, catalog, preset: GenerationPreset.simpler),
  ),
  GalleryVariant(
    id: 't47-balanced',
    title: 'T47: сбалансированно',
    build: (image, target, catalog) => _request(image, target, catalog, preset: GenerationPreset.balanced),
  ),
  GalleryVariant(
    id: 't47-detailed',
    title: 'T47: детально',
    build: (image, target, catalog) => _request(image, target, catalog, preset: GenerationPreset.detailed),
  ),
  GalleryVariant(
    id: 't54-faces',
    title: 'T54: лица (цвета кожи, зрачки, губы)',
    build: (image, target, catalog) =>
        _request(image, target, catalog, preset: GenerationPreset.balanced, masks: galleryFaces[image]),
  ),
  GalleryVariant(
    id: 't62-catalog-all',
    title: 'T47 + весь каталог 11/0 (обе серии, все отделки; как до T62)',
    beadsOnly: true,
    catalog: true,
    build: (image, target, catalog) =>
        _request(
          image,
          target,
          catalog,
          useCatalog: true,
          preset: GenerationPreset.balanced,
        ).withConstraint(
          PaletteConstraint.catalog(
            <CatalogColor>[
              for (final CatalogColor c in catalog)
                if (c.sizeCode == '11/0') c,
            ],
            material: CatalogMaterial.bead,
          ),
        ),
  ),
  GalleryVariant(
    id: 't47-catalog',
    title: 'T47: сбалансированно + каталог Toho/Delica',
    beadsOnly: true,
    catalog: true,
    build: (image, target, catalog) =>
        _request(image, target, catalog, useCatalog: true, preset: GenerationPreset.balanced),
  ),
  GalleryVariant(
    id: 't57-dither',
    title: 'T57: сбалансированно + плавные переходы',
    build: (image, target, catalog) =>
        _request(image, target, catalog, preset: GenerationPreset.balanced, dither: true),
  ),
  GalleryVariant(
    id: 't57-dither-catalog',
    title: 'T57: плавные переходы + каталог Toho/Delica',
    beadsOnly: true,
    catalog: true,
    build: (image, target, catalog) =>
        _request(image, target, catalog, useCatalog: true, preset: GenerationPreset.balanced, dither: true),
  ),
  GalleryVariant(
    id: 't55-simplify',
    title: 'T55: фон упрощён',
    build: (image, target, catalog) => _request(
      image,
      target,
      catalog,
      preset: GenerationPreset.balanced,
    ).withBackground(mask: standInSubjectMask(image), mode: BackgroundMode.simplify),
  ),
  GalleryVariant(
    id: 't55-remove',
    title: 'T55: фон убран',
    build: (image, target, catalog) => _request(
      image,
      target,
      catalog,
      preset: GenerationPreset.balanced,
    ).withBackground(mask: standInSubjectMask(image), mode: BackgroundMode.remove),
  ),
  GalleryVariant(
    id: 't55-outline',
    title: 'T55: обводка (бисер)',
    beadsOnly: true,
    build: (image, target, catalog) => _request(
      image,
      target,
      catalog,
      preset: GenerationPreset.balanced,
    ).withBackground(mask: standInSubjectMask(image), mode: BackgroundMode.simplify, outline: true),
  ),
];

/// Заменитель маски объекта для листов галереи (на устройстве маску даёт Vision, T48): пиксели, заметно
/// отличающиеся от цвета рамки кадра, все крупные (от десятой доли наибольшей) связные области с закрытыми дырами; если так не вышло
/// (объект занимает меньше 5 % или больше 95 % кадра), центральный эллипс.
Uint8List standInSubjectMask(SourceImage image) {
  final int w = image.width;
  final int h = image.height;
  final List<Lab> border = <Lab>[];
  Lab at(int x, int y) {
    final int o = (y * w + x) * 4;
    return Lab.fromRgb(Rgb(image.rgba[o], image.rgba[o + 1], image.rgba[o + 2]));
  }

  for (int x = 0; x < w; x++) {
    border
      ..add(at(x, 0))
      ..add(at(x, h - 1));
  }
  for (int y = 0; y < h; y++) {
    border
      ..add(at(0, y))
      ..add(at(w - 1, y));
  }
  double median(List<double> v) => (v..sort())[v.length ~/ 2];
  final Lab bg = Lab(
    median(<double>[for (final Lab c in border) c.l]),
    median(<double>[for (final Lab c in border) c.a]),
    median(<double>[for (final Lab c in border) c.b]),
  );
  // Рамка кадра должна быть почти однотонной (плоский фон), иначе по цвету объект не найти.
  final int flat = border.where((c) => deltaE2000(c, bg) <= 10).length;
  final bool flatBackground = flat >= border.length * 0.85;
  final Uint8List raw = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      if (flatBackground && deltaE2000(at(x, y), bg) > 12) raw[y * w + x] = 1;
    }
  }
  // Наибольшая связная область объекта.
  final Int32List label = Int32List(w * h);
  final List<int> sizes = <int>[0];
  for (int start = 0; start < raw.length; start++) {
    if (raw[start] == 0 || label[start] != 0) continue;
    final int id = sizes.length;
    int size = 0;
    final List<int> stack = <int>[start];
    label[start] = id;
    while (stack.isNotEmpty) {
      final int p = stack.removeLast();
      size++;
      final int x = p % w;
      final int y = p ~/ w;
      for (final (int dx, int dy) in const <(int, int)>[(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final int nx = x + dx;
        final int ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        final int q = ny * w + nx;
        if (raw[q] == 1 && label[q] == 0) {
          label[q] = id;
          stack.add(q);
        }
      }
    }
    sizes.add(size);
  }
  int bestLabel = 0;
  for (int i = 1; i < sizes.length; i++) {
    if (bestLabel == 0 || sizes[i] > sizes[bestLabel]) bestLabel = i;
  }
  final Uint8List mask = Uint8List(w * h);
  if (bestLabel != 0) {
    for (int i = 0; i < mask.length; i++) {
      if (label[i] != 0 && sizes[label[i]] * 10 >= sizes[bestLabel]) mask[i] = 255;
    }
    // Закрываем дыры: фон, до которого нельзя дойти от рамки кадра, тоже объект.
    final Uint8List reach = Uint8List(w * h);
    final List<int> stack = <int>[];
    void seed(int x, int y) {
      final int p = y * w + x;
      if (mask[p] == 0 && reach[p] == 0) {
        reach[p] = 1;
        stack.add(p);
      }
    }

    for (int x = 0; x < w; x++) {
      seed(x, 0);
      seed(x, h - 1);
    }
    for (int y = 0; y < h; y++) {
      seed(0, y);
      seed(w - 1, y);
    }
    while (stack.isNotEmpty) {
      final int p = stack.removeLast();
      final int x = p % w;
      final int y = p ~/ w;
      if (x > 0) seed(x - 1, y);
      if (x < w - 1) seed(x + 1, y);
      if (y > 0) seed(x, y - 1);
      if (y < h - 1) seed(x, y + 1);
    }
    for (int i = 0; i < mask.length; i++) {
      if (reach[i] == 0) mask[i] = 255;
    }
  }
  final int inside = mask.where((v) => v != 0).length;
  if (inside >= w * h * 0.05 && inside <= w * h * 0.95) return mask;
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final double dx = (x - w / 2) / (w * 0.38);
      final double dy = (y - h / 2) / (h * 0.42);
      mask[y * w + x] = dx * dx + dy * dy <= 1 ? 255 : 0;
    }
  }
  return mask;
}

/// Бисерный каталог приложения (Toho Round и Miyuki Delica 11/0), как его видит мастер.
List<CatalogColor> loadBeadCatalog() {
  final List<CatalogColor> colors = <CatalogColor>[];
  for (final FileSystemEntity entity in Directory('assets/catalog').listSync()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final String id = entity.uri.pathSegments.last.replaceAll('.json', '');
    final CatalogFile? file = parseCatalogFile(id, entity.readAsStringSync()).valueOrNull;
    if (file != null) colors.addAll(file.colors);
  }
  return colors;
}

/// Читает и декодирует фикстуры; личные фото из [privateDir] (в git не попадают) добавляются с приставкой `private-`.
///
/// Вызывать внутри `tester.runAsync`: декодирование идёт через движок.
Future<List<GalleryPhoto>> loadPhotos({String? privateDir}) async {
  const UiImageDecoder decoder = UiImageDecoder();
  final List<GalleryPhoto> photos = <GalleryPhoto>[];
  Future<void> add(String prefix, Directory dir, int maxSide) async {
    if (!dir.existsSync()) return;
    final List<File> files = <File>[
      for (final FileSystemEntity e in dir.listSync())
        if (e is File && _imageExtensions.contains(_extension(e.path))) e,
    ]..sort((a, b) => a.path.compareTo(b.path));
    for (final File file in files) {
      final SourceImage? image = (await decoder.decode(file.readAsBytesSync(), maxSide: maxSide)).valueOrNull;
      if (image == null) continue;
      final String base = file.uri.pathSegments.last;
      final String name = '$prefix${base.substring(0, base.lastIndexOf('.'))}';
      if (name == 'portrait') galleryFaces[image] = _portraitFaces();
      photos.add(GalleryPhoto(name, image));
    }
  }

  await add('', Directory(photosDir), 1024);
  if (privateDir != null && privateDir.isNotEmpty) await add('private-', Directory(privateDir), 512);
  return photos;
}

String _extension(String path) {
  final int dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot).toLowerCase();
}

/// Результат одного прогона: фото × вид × вариант.
final class GalleryRun {
  const GalleryRun({required this.photo, required this.target, required this.variant, required this.pattern});

  final GalleryPhoto photo;
  final GalleryTarget target;
  final GalleryVariant variant;
  final GeneratedPattern pattern;

  String get key => '${photo.name}/${target.id}/${variant.id}';
  GenerationStats get stats => pattern.stats!;
}

/// Прогоняет все фото через все виды и варианты.
///
/// С [includeLarge] добавляются крупные размеры [galleryLargeTargets] (только свободная палитра).
List<GalleryRun> runGallery(List<GalleryPhoto> photos, List<CatalogColor> catalog, {bool includeLarge = false}) {
  const ImageToGridPipeline pipeline = ImageToGridPipeline();
  return <GalleryRun>[
    for (final GalleryPhoto photo in photos)
      for (final GalleryTarget target in <GalleryTarget>[...galleryTargets, if (includeLarge) ...galleryLargeTargets])
        for (final GalleryVariant variant in galleryVariants)
          if (variant.appliesTo(target))
            GalleryRun(
              photo: photo,
              target: target,
              variant: variant,
              pattern: pipeline.run(variant.build(photo.image, target, catalog)),
            ),
  ];
}

/// Лица в клетках схемы прогона [run] или `null`, если у фото нет размеченных лиц.
FaceCells? faceCellsOf(GalleryRun run) {
  final ImageMaskSet? masks = galleryFaces[run.photo.image];
  if (masks == null) return null;
  final int columns = run.pattern.grid.width;
  final int rows = run.pattern.grid.height;
  final WorkImage work = WorkImage.fromSource(
    image: run.photo.image,
    geometry: run.target.geometry,
    metrics: run.target.metrics,
    columns: columns,
    rows: rows,
  );
  final CellRegions regions = CellRegions.forGrid(
    geometry: run.target.geometry,
    metrics: run.target.metrics,
    columns: columns,
    rows: rows,
    imageWidth: work.width,
    imageHeight: work.height,
  );
  return FaceGuide(masks).cells(regions, workWidth: work.width, workHeight: work.height);
}

/// Метрики прогонов в виде, в котором они лежат в `baseline.json`.
Map<String, Map<String, num>> baselineOf(List<GalleryRun> runs) => <String, Map<String, num>>{
  for (final GalleryRun run in runs)
    run.key: <String, num>{
      'singles': run.stats.singleCells,
      'colors': run.stats.colorCount,
      'deltaE': double.parse(run.stats.meanDeltaE.toStringAsFixed(2)),
      if (run.stats.contrast != null) 'contrast': double.parse(run.stats.contrast!.toStringAsFixed(3)),
      if (run.stats.lightnessCorrelation != null)
        'corr': double.parse(run.stats.lightnessCorrelation!.toStringAsFixed(3)),
    },
};

/// Пишет базу метрик (ключи по порядку, для читаемого diff).
void writeBaseline(Map<String, Map<String, num>> baseline) {
  final List<String> keys = baseline.keys.toList()..sort();
  const JsonEncoder encoder = JsonEncoder.withIndent('  ');
  File(
    baselinePath,
  ).writeAsStringSync('${encoder.convert(<String, Object>{for (final String k in keys) k: baseline[k]!})}\n');
}

/// Читает базу метрик.
Map<String, Map<String, num>> readBaseline() {
  final Map<String, Object?> raw = jsonDecode(File(baselinePath).readAsStringSync()) as Map<String, Object?>;
  return <String, Map<String, num>>{
    for (final MapEntry<String, Object?> e in raw.entries)
      e.key: <String, num>{
        for (final MapEntry<String, Object?> m in (e.value! as Map<String, Object?>).entries) m.key: m.value! as num,
      },
  };
}

/// Таблица метрик в Markdown.
String metricsTable(List<GalleryRun> runs) {
  final StringBuffer out = StringBuffer()
    ..writeln(
      '| Фото | Вид | Вариант | Цветов | Одиночных клеток | Одиночных, % | Средняя ΔE2000 | Контраст | Корреляция | Время, мс (выборка / палитра / привязка / шаги) |',
    )
    ..writeln('|---|---|---|---|---|---|---|---|---|---|');
  for (final GalleryRun run in runs) {
    final GenerationStats s = run.stats;
    String ms(String stage) => (s.stageTimes[stage]!.inMicroseconds / 1000).toStringAsFixed(1);
    out.writeln(
      '| ${run.photo.name} | ${run.target.id} | ${run.variant.title} | ${s.colorCount} | ${s.singleCells}${s.singleCellsBefore == null ? '' : ' (было ${s.singleCellsBefore})'} | '
      '${(100 * s.singleCells / (run.pattern.grid.width * run.pattern.grid.height)).toStringAsFixed(1)} | '
      '${s.meanDeltaE.toStringAsFixed(1)} | ${s.contrast?.toStringAsFixed(2) ?? '—'} | '
      '${s.lightnessCorrelation?.toStringAsFixed(3) ?? '—'} | ${ms('sample')} / ${ms('palette')} / ${ms('assign')} / ${ms('steps')} |',
    );
  }
  return out.toString();
}

const int _panelHeight = 360;
const int _realisticPanelHeight = 600;
const int _gap = 12;

/// Лист «до / после» одного фото и одного вида: слева фото, правее — варианты по порядку (плоский вид).
///
/// С [realistic] схемы нарисованы тем же кодом, что вид «как будет выглядеть» в приложении (бусины с бликом,
/// крестики на канве), и крупнее: иначе у бусины в 8 пикселей блика не видно.
Future<Uint8List> renderSheet(
  GalleryPhoto photo,
  GalleryTarget target,
  List<GalleryRun> runs, {
  bool realistic = false,
}) async {
  final int panelHeight = realistic ? _realisticPanelHeight : _panelHeight;
  final List<_Panel> panels = <_Panel>[
    _photoPanel(photo.image, runs.first, panelHeight),
    for (final GalleryRun run in runs) realistic ? await _realisticPanel(run, panelHeight) : _patternPanel(run),
  ];
  final int width = panels.fold<int>(_gap, (sum, p) => sum + p.width + _gap);
  final int height = panelHeight + 2 * _gap;
  final Uint8List rgba = Uint8List(width * height * 4);
  for (int i = 0; i < rgba.length; i += 4) {
    rgba[i] = 245;
    rgba[i + 1] = 245;
    rgba[i + 2] = 245;
    rgba[i + 3] = 255;
  }
  int left = _gap;
  for (final _Panel panel in panels) {
    for (int y = 0; y < panelHeight; y++) {
      final int from = y * panel.width * 4;
      rgba.setRange(((y + _gap) * width + left) * 4, ((y + _gap) * width + left + panel.width) * 4, panel.rgba, from);
    }
    left += panel.width + _gap;
  }
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, width, height, ui.PixelFormat.rgba8888, completer.complete);
  final ui.Image image = await completer.future;
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}

final class _Panel {
  const _Panel(this.width, this.rgba);

  final int width;
  final Uint8List rgba;
}

_Panel _photoPanel(SourceImage image, GalleryRun run, int panelHeight) {
  final MmSize extent = run.target.geometry.extent(
    run.target.metrics,
    columns: run.pattern.grid.width,
    rows: run.pattern.grid.height,
  );
  final int width = (panelHeight * extent.width / extent.height).round();
  final Uint8List out = Uint8List(width * panelHeight * 4);
  for (int y = 0; y < panelHeight; y++) {
    for (int x = 0; x < width; x++) {
      final int sx = (x * image.width / width).floor().clamp(0, image.width - 1);
      final int sy = (y * image.height / panelHeight).floor().clamp(0, image.height - 1);
      final int from = (sy * image.width + sx) * 4;
      final int to = (y * width + x) * 4;
      out.setRange(to, to + 3, image.rgba, from);
      out[to + 3] = 255;
    }
  }
  return _Panel(width, out);
}

/// Округление до пикселя без щелей между клетками: границы вида 292,4999 и 292,5001 считаются одной.
int _px(double value) => ((value * 1000).round() / 1000).round();

_Panel _patternPanel(GalleryRun run) {
  final GalleryTarget target = run.target;
  final int columns = run.pattern.grid.width;
  final int rows = run.pattern.grid.height;
  final MmSize extent = target.geometry.extent(target.metrics, columns: columns, rows: rows);
  final MmSize cell = target.geometry.cellSize(target.metrics);
  final double scale = _panelHeight / extent.height;
  final int width = (extent.width * scale).round();
  final Uint8List out = Uint8List(width * _panelHeight * 4);
  for (int i = 0; i < out.length; i += 4) {
    out[i] = 255;
    out[i + 1] = 255;
    out[i + 2] = 255;
    out[i + 3] = 255;
  }
  for (int row = 0; row < rows; row++) {
    for (int column = 0; column < columns; column++) {
      final int value = run.pattern.grid.at(column, row);
      if (value == 0) continue;
      final Rgb color = run.pattern.palette[value - 1].rgb;
      final MmPoint center = target.geometry.cellCenter(target.metrics, CellPosition(column, row));
      final int x0 = _px((center.x - cell.width / 2) * scale).clamp(0, width);
      final int x1 = _px((center.x + cell.width / 2) * scale).clamp(0, width);
      final int y0 = _px((center.y - cell.height / 2) * scale).clamp(0, _panelHeight);
      final int y1 = _px((center.y + cell.height / 2) * scale).clamp(0, _panelHeight);
      for (int y = y0; y < y1; y++) {
        for (int x = x0; x < x1; x++) {
          final int to = (y * width + x) * 4;
          out[to] = color.r;
          out[to + 1] = color.g;
          out[to + 2] = color.b;
        }
      }
    }
  }
  return _Panel(width, out);
}

/// Панель схемы в реалистичном виде: тот же `RealisticCells`, что рисует приложение.
Future<_Panel> _realisticPanel(GalleryRun run, int panelHeight) async {
  final GalleryTarget target = run.target;
  final MmSize extent = target.geometry.extent(
    target.metrics,
    columns: run.pattern.grid.width,
    rows: run.pattern.grid.height,
  );
  final MmSize cell = target.geometry.cellSize(target.metrics);
  final double pxPerMm = panelHeight / extent.height;
  final GridScene scene = GridScene(
    geometry: target.geometry,
    metrics: target.metrics,
    columns: run.pattern.grid.width,
    rows: run.pattern.grid.height,
    smallestCellPx: pxPerMm * math.min(cell.width, cell.height),
  );
  final int width = scene.size.width.round();
  final RealisticMaterial material = RealisticMaterial.forMetrics(target.metrics);
  const RealisticColors beadColors = RealisticColors(surface: Color(0xFFE6E1D8), thread: Color(0xFF9A948A));
  const RealisticColors clothColors = RealisticColors(surface: Color(0xFFF2EBDB), thread: Color(0xFF9A948A));
  final RealisticColors colors = material.isBead ? beadColors : clothColors;
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  RealisticCells.paintSurface(canvas, ui.Rect.fromLTWH(0, 0, width.toDouble(), panelHeight.toDouble()), colors);
  RealisticCells.paintBlock(
    canvas,
    scene: scene,
    grid: run.pattern.grid,
    palette: paletteFromGenerated(run.pattern).valueOrNull!,
    colors: colors,
    material: material,
    c0: 0,
    c1: run.pattern.grid.width,
    r0: 0,
    r1: run.pattern.grid.height,
  );
  final ui.Image image = await recorder.endRecording().toImage(width, panelHeight);
  final ByteData? data = await image.toByteData();
  image.dispose();
  return _Panel(width, data!.buffer.asUint8List());
}
