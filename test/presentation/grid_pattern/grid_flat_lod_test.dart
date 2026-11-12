import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/grid.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/presentation/grid_pattern/grid_layer_cache.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glass_harness.dart';
import 'grid_fixtures.dart';

const GridPaintStyle _style = GridPaintStyle(
  line: Color(0xFF000000),
  boldLine: Color(0xFF000000),
  emptyCell: Color(0xFF000000),
  unknown: Color(0xFF000000),
);

Widget _view({
  required GridLayerCache cache,
  TransformationController? controller,
  int columns = 12,
  bool interactive = true,
}) => SizedBox(
  width: 360,
  height: 640,
  child: GridPatternView(
    grid: sampleGrid(width: columns, height: columns),
    palette: samplePalette(),
    geometry: const GridGeometry.rectangular(),
    metrics: BeadSize.delica11,
    options: const GridViewOptions(showGridLines: false),
    controller: controller,
    interactive: interactive,
    layerCache: cache,
  ),
);

void main() {
  group('обзорный слой ячеек', () {
    test('сплошная заливка без зазоров между клетками одного цвета', () async {
      final Grid grid = Grid.fromCells(width: 4, height: 1, cells: const <int>[1, 1, 1, 2]);
      final GridScene scene = GridScene(
        geometry: const GridGeometry.rectangular(),
        metrics: BeadSize.delica11,
        columns: 4,
        rows: 1,
      );
      final GridLayerCache cache = GridLayerCache()
        ..configure(
          grid: grid,
          palette: samplePalette(),
          scene: scene,
          options: const GridViewOptions(showGridLines: false),
          style: _style,
          flat: true,
        );
      addTearDown(cache.dispose);
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      cache.paintVisible(Canvas(recorder), Offset.zero & scene.size);
      final ui.Image image = await recorder.endRecording().toImage(scene.size.width.ceil(), scene.size.height.ceil());
      final ByteData data = (await image.toByteData())!;
      int alpha(double x, double y) => data.getUint8(((y.round() * image.width + x.round()) * 4) + 3);
      final double cell = scene.cellSize.width;
      final double mid = scene.size.height / 2;
      // Граница клеток 0 и 1 одного цвета закрашена (у подробной отрисовки там зазор между бусинами).
      expect(alpha(cell, mid), 255);
      expect(alpha(cell * 2, mid), 255, reason: 'и граница двух разных цветов');
      expect(cache.flat, isTrue);
    });

    test('смена детализации сбрасывает блоки, повторная настройка — нет', () {
      final Grid grid = sampleGrid();
      final GridScene scene = GridScene(
        geometry: const GridGeometry.rectangular(),
        metrics: BeadSize.delica11,
        columns: grid.width,
        rows: grid.height,
      );
      final GridLayerCache cache = GridLayerCache();
      addTearDown(cache.dispose);
      void configure({required bool flat}) => cache.configure(
        grid: grid,
        palette: samplePalette(),
        scene: scene,
        options: const GridViewOptions(),
        style: _style,
        flat: flat,
      );
      configure(flat: false);
      cache.paintVisible(Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
      final int built = cache.buildCount;
      configure(flat: false);
      cache.paintVisible(Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
      expect(cache.buildCount, built);
      configure(flat: true);
      cache.paintVisible(Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
      expect(cache.buildCount, built * 2);
    });
  });

  group('вид выбирает детализацию по размеру клетки на экране', () {
    testWidgets('зум: мельче 4 пикселей — обзор; с зазором до 5,5 назад не прыгает', (tester) async {
      final GridLayerCache cache = GridLayerCache();
      addTearDown(cache.dispose);
      final TransformationController controller = TransformationController();
      addTearDown(controller.dispose);
      await pumpGlass(tester, _view(cache: cache, controller: controller));
      expect(cache.flat, isFalse);

      controller.value = Matrix4.identity()..scaleByDouble(0.1, 0.1, 1, 1);
      await tester.pump();
      expect(cache.flat, isTrue);

      // Клетка 22 px × 0,2 = 4,4 px: больше порога обзора, но меньше порога возврата — остаёмся в обзоре.
      controller.value = Matrix4.identity()..scaleByDouble(0.2, 0.2, 1, 1);
      await tester.pump();
      expect(cache.flat, isTrue);

      controller.value = Matrix4.identity()..scaleByDouble(0.3, 0.3, 1, 1);
      await tester.pump();
      expect(cache.flat, isFalse);
    });

    testWidgets('неинтерактивный предпросмотр: плотная схема в окне обзорная, редкая нет', (tester) async {
      final GridLayerCache dense = GridLayerCache();
      final GridLayerCache sparse = GridLayerCache();
      addTearDown(dense.dispose);
      addTearDown(sparse.dispose);
      await pumpGlass(tester, _view(cache: dense, columns: 300, interactive: false));
      await pumpGlass(tester, _view(cache: sparse, interactive: false));
      expect(dense.flat, isTrue);
      expect(sparse.flat, isFalse);
    });
  });
}
