import 'dart:convert';
import 'dart:typed_data';

import 'package:beading/domain/catalog/bead_finish_group.dart';
import 'package:beading/domain/catalog/bead_series.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
import 'package:beading/domain/image_to_grid/generation_stamp.dart';
import 'package:beading/domain/image_to_grid/image_recipe.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/image_to_grid/importance_brush.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_image_pattern.dart';

void main() {
  final ImageRecipe recipe = ImageRecipe(
    source: Uint8List.fromList(<int>[1, 2, 3]),
    quarterTurns: 3,
    crop: const CropRect(left: 0.1, top: 0.2, right: 0.9, bottom: 0.8),
    brush: const ImportanceBrush(<BrushStroke>[
      BrushStroke(points: <double>[0.1, 0.2, 0.3, 0.4], radius: 0.04),
    ]),
    flossBrand: 'Anchor',
    settings: ImageToGridSettings(
      technique: Technique.crossStitch,
      columns: 77,
      maxColors: 33,
      paletteSource: PaletteSource.free,
      beadSeries: BeadSeries.values.first,
      finishGroups: const <BeadFinishGroup>{BeadFinishGroup.solid},
      dither: true,
      useMasks: false,
      preset: GenerationPreset.simpler,
      background: BackgroundMode.values.last,
      outline: true,
      fabric: Fabric.standard.withColor(const Rgb(10, 20, 30)),
      backstitch: true,
      blends: false,
      otherBrands: true,
      otherBrandsOnly: const <String>{'Anchor', 'ПНК Кирова'},
      shadows: 30,
      onlyStash: true,
      mixedStitches: true,
    ),
  );

  test('рецепт записывается и читается без потерь', () {
    final ImageRecipe? back = ImageRecipeCodec.decode(ImageRecipeCodec.encode(recipe), recipe.source);
    expect(back, recipe);
  });

  test('основной производитель ниток пишется и читается; в старом рецепте его нет (T101)', () {
    final Map<String, Object?> json = jsonDecode(ImageRecipeCodec.encode(recipe)) as Map<String, Object?>;
    expect((json['settings']! as Map<String, Object?>)['flossBrand'], 'Anchor');
    (json['settings']! as Map<String, Object?>).remove('flossBrand');
    final ImageRecipe? old = ImageRecipeCodec.decode(jsonEncode(json), recipe.source);
    expect(old, isNotNull);
    expect(old!.flossBrand, isEmpty);
  });

  test('старый рецепт без ключа запаса читается с выключенным запасом (T34)', () {
    final Map<String, Object?> json = jsonDecode(ImageRecipeCodec.encode(recipe)) as Map<String, Object?>;
    (json['settings']! as Map<String, Object?>).remove('stash');
    final ImageRecipe? old = ImageRecipeCodec.decode(jsonEncode(json), recipe.source);
    expect(old, isNotNull);
    expect(old!.settings.onlyStash, isFalse);
  });

  test('старый рецепт без ключа брендов читается с выключенным переключателем (T86)', () {
    final Map<String, Object?> json = jsonDecode(ImageRecipeCodec.encode(recipe)) as Map<String, Object?>;
    (json['settings']! as Map<String, Object?>).remove('otherBrands');
    final ImageRecipe? old = ImageRecipeCodec.decode(jsonEncode(json), recipe.source);
    expect(old, isNotNull);
    expect(old!.settings.otherBrands, isFalse);
  });

  test('старый рецепт без списка брендов добора читается как «Авто» (T90)', () {
    final Map<String, Object?> json = jsonDecode(ImageRecipeCodec.encode(recipe)) as Map<String, Object?>;
    (json['settings']! as Map<String, Object?>).remove('otherBrandsOnly');
    final ImageRecipe? old = ImageRecipeCodec.decode(jsonEncode(json), recipe.source);
    expect(old, isNotNull);
    expect(old!.settings.otherBrandsOnly, isEmpty);
  });

  test('старый рецепт без ключа теней читается как «Авто» (T87)', () {
    final Map<String, Object?> json = jsonDecode(ImageRecipeCodec.encode(recipe)) as Map<String, Object?>;
    (json['settings']! as Map<String, Object?>).remove('shadows');
    final ImageRecipe? old = ImageRecipeCodec.decode(jsonEncode(json), recipe.source);
    expect(old, isNotNull);
    expect(old!.settings.shadows, isNull);
  });

  test('«Авто» в рецепте остаётся «Авто», ручная сила — ручной (T87)', () {
    final ImageRecipe auto = ImageRecipe(
      source: recipe.source,
      quarterTurns: 0,
      crop: CropRect.full,
      brush: ImportanceBrush.empty,
      settings: recipe.settings.copyWith(clearShadows: true),
    );
    expect(ImageRecipeCodec.decode(ImageRecipeCodec.encode(auto), auto.source)!.settings.shadows, isNull);
    expect(ImageRecipeCodec.decode(ImageRecipeCodec.encode(recipe), recipe.source)!.settings.shadows, 30);
  });

  test('рецепт без предустановки остаётся без неё', () {
    final ImageRecipe plain = ImageRecipe(
      source: recipe.source,
      quarterTurns: 0,
      crop: CropRect.full,
      brush: ImportanceBrush.empty,
      settings: recipe.settings.copyWith(clearPreset: true),
    );
    expect(ImageRecipeCodec.decode(ImageRecipeCodec.encode(plain), plain.source)?.settings.preset, isNull);
  });

  test('повреждённая запись даёт null', () {
    expect(ImageRecipeCodec.decode('{', recipe.source), isNull);
    expect(ImageRecipeCodec.decode('{"v":1}', recipe.source), isNull);
  });

  test('хранилище: сохранить, прочитать, удалить', () async {
    final ImageRecipeStore store = ImageRecipeStore(FakeFileStore());
    expect(await store.load('p'), isNull);
    await store.save('p', recipe);
    expect(await store.load('p'), recipe);
    await store.delete('p');
    expect(await store.load('p'), isNull);
  });

  test('высота и подгонка (T88a) пишутся и читаются', () {
    final ImageRecipe withRows = ImageRecipe(
      source: recipe.source,
      quarterTurns: recipe.quarterTurns,
      crop: recipe.crop,
      brush: recipe.brush,
      settings: recipe.settings.copyWith(rows: 50, fit: FrameFit.margins),
    );
    final ImageRecipe? back = ImageRecipeCodec.decode(ImageRecipeCodec.encode(withRows), recipe.source);
    expect(back, withRows);
    expect(back!.settings.rows, 50);
    expect(back.settings.fit, FrameFit.margins);
  });

  test('старый рецепт без rows и fit читается с высотой по фото', () {
    final Map<String, Object?> json = jsonDecode(ImageRecipeCodec.encode(recipe)) as Map<String, Object?>;
    final Map<String, Object?> settings = json['settings']! as Map<String, Object?>;
    expect(settings.containsKey('rows'), isFalse);
    settings
      ..remove('rows')
      ..remove('fit');
    final ImageRecipe? old = ImageRecipeCodec.decode(jsonEncode(json), recipe.source);
    expect(old, isNotNull);
    expect(old!.settings.rows, isNull);
    expect(old.settings.fit, FrameFit.crop);
    expect(json['v'], 1);
  });

  test('неизвестная подгонка читается как обрезка', () {
    final Map<String, Object?> json = jsonDecode(ImageRecipeCodec.encode(recipe)) as Map<String, Object?>;
    (json['settings']! as Map<String, Object?>)
      ..['rows'] = 40
      ..['fit'] = 'unknown';
    final ImageRecipe? back = ImageRecipeCodec.decode(jsonEncode(json), recipe.source);
    expect(back!.settings.rows, 40);
    expect(back.settings.fit, FrameFit.crop);
  });

  group('отпечаток генерации (T104)', () {
    const GenerationBuild build = GenerationBuild(app: '0.6.0 (1)', commit: 'a1b2c3d4e5', algo: 7);

    test('записывается, читается и переживает пересохранение', () {
      final ImageRecipe stamped = recipe.stamped(build);
      expect(stamped.stamp!.build, build);
      final ImageRecipe? back = ImageRecipeCodec.decode(ImageRecipeCodec.encode(stamped), recipe.source);
      expect(back, stamped);
      final ImageRecipe? again = ImageRecipeCodec.decode(ImageRecipeCodec.encode(back!), recipe.source);
      expect(again!.stamp, stamped.stamp);
    });

    test('у рецепта без отпечатка версия неизвестна, лишних ключей нет', () {
      final Map<String, Object?> json = jsonDecode(ImageRecipeCodec.encode(recipe)) as Map<String, Object?>;
      expect(json.containsKey('gen'), isFalse);
      expect(ImageRecipeCodec.decode(jsonEncode(json), recipe.source)!.stamp, isNull);
    });

    test('непонятный gen читается как неизвестная версия', () {
      final Map<String, Object?> json = jsonDecode(ImageRecipeCodec.encode(recipe)) as Map<String, Object?>;
      json['gen'] = <String, Object?>{'algo': 'x'};
      final ImageRecipe? back = ImageRecipeCodec.decode(jsonEncode(json), recipe.source);
      expect(back, isNotNull);
      expect(back!.stamp, isNull);
    });

    test('хэш параметров: те же параметры дают тот же хэш, другие дают другой; фото в него не входит', () {
      final String base = ImageRecipeCodec.configHash(recipe);
      expect(base, hasLength(12));
      expect(ImageRecipeCodec.configHash(recipe), base);
      final ImageRecipe otherPhoto = ImageRecipe(
        source: Uint8List.fromList(<int>[9, 9]),
        quarterTurns: recipe.quarterTurns,
        crop: recipe.crop,
        brush: recipe.brush,
        settings: recipe.settings,
        flossBrand: recipe.flossBrand,
      );
      expect(ImageRecipeCodec.configHash(otherPhoto), base);
      expect(otherPhoto.stamped(build).stamp!.src, isNot(recipe.stamped(build).stamp!.src));
      final ImageRecipe otherColors = ImageRecipe(
        source: recipe.source,
        quarterTurns: recipe.quarterTurns,
        crop: recipe.crop,
        brush: recipe.brush,
        settings: recipe.settings.copyWith(maxColors: 34),
        flossBrand: recipe.flossBrand,
      );
      expect(ImageRecipeCodec.configHash(otherColors), isNot(base));
    });

    test('хэш не зависит от порядка наборов в настройках', () {
      final ImageRecipe a = ImageRecipe(
        source: recipe.source,
        quarterTurns: 0,
        crop: recipe.crop,
        brush: recipe.brush,
        settings: recipe.settings.copyWith(otherBrandsOnly: <String>{'Anchor', 'DMC'}),
      );
      final ImageRecipe b = ImageRecipe(
        source: recipe.source,
        quarterTurns: 0,
        crop: recipe.crop,
        brush: recipe.brush,
        settings: recipe.settings.copyWith(otherBrandsOnly: <String>{'DMC', 'Anchor'}),
      );
      expect(ImageRecipeCodec.configHash(a), ImageRecipeCodec.configHash(b));
    });
  });
}
