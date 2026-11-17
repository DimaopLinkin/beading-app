import 'dart:convert';
import 'dart:typed_data';

import 'package:beading/domain/catalog/bead_finish_group.dart';
import 'package:beading/domain/catalog/bead_series.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/domain/image_to_grid/background_stage.dart';
import 'package:beading/domain/image_to_grid/generation_preset.dart';
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
      shadows: 30,
      onlyStash: true,
      mixedStitches: true,
    ),
  );

  test('рецепт записывается и читается без потерь', () {
    final ImageRecipe? back = ImageRecipeCodec.decode(ImageRecipeCodec.encode(recipe), recipe.source);
    expect(back, recipe);
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
}
