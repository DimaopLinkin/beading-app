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
    ),
  );

  test('рецепт записывается и читается без потерь', () {
    final ImageRecipe? back = ImageRecipeCodec.decode(ImageRecipeCodec.encode(recipe), recipe.source);
    expect(back, recipe);
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
