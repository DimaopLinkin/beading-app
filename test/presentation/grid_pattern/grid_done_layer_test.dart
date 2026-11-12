import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/presentation/grid_pattern/grid_done_layer.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

GridScene _scene({int columns = 200, int rows = 200}) =>
    GridScene(geometry: const GridGeometry.rectangular(), metrics: Fabric.standard, columns: columns, rows: rows);

CellProgress _filled(int columns, int rows, {int width = 200}) =>
    CellProgress(
      width: width,
    ).withCells(<CellPosition>[
      for (int r = 0; r < rows; r++)
        for (int c = 0; c < columns; c++) CellPosition(c, r),
    ], done: true);

const Color _veil = Color(0x40FFFFFF);

void main() {
  late GridDoneLayerCache cache;
  setUp(() => cache = GridDoneLayerCache());
  tearDown(() => cache.dispose());

  test('строит только блоки с отметками, попавшие в видимую область', () {
    final GridScene scene = _scene();
    // Залито 100×100 клеток: 7×7 блоков по 16 клеток (правый нижний блок неполный).
    cache
      ..configure(scene: scene, progress: _filled(100, 100), veil: _veil)
      ..paintVisible(ui.Canvas(ui.PictureRecorder()), const Rect.fromLTWH(0, 0, 1, 1));
    expect(cache.buildCount, 1, reason: 'видна одна клетка — один блок');

    cache.paintVisible(ui.Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
    expect(cache.buildCount, 49, reason: 'пустые блоки за пределами залитого не строятся');
    expect(cache.cachedBlocks, 49);
  });

  test('повторная настройка тем же прогрессом ничего не сбрасывает', () {
    final GridScene scene = _scene();
    final CellProgress progress = _filled(40, 40);
    expect(cache.configure(scene: scene, progress: progress, veil: _veil), isTrue);
    cache.paintVisible(ui.Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
    final int built = cache.buildCount;
    expect(cache.configure(scene: scene, progress: progress, veil: _veil), isFalse);
    expect(
      cache.configure(scene: _scene(), progress: _filled(40, 40), veil: _veil),
      isFalse,
      reason: 'равны по значению',
    );
    cache.paintVisible(ui.Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
    expect(cache.buildCount, built);
  });

  test('отметка одной клетки пересобирает только её блок', () {
    final GridScene scene = _scene();
    final CellProgress before = _filled(100, 100);
    cache
      ..configure(scene: scene, progress: before, veil: _veil)
      ..paintVisible(ui.Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
    final int built = cache.buildCount;

    expect(
      cache.configure(
        scene: scene,
        progress: before.withCells(const <CellPosition>[CellPosition(150, 150)], done: true),
        veil: _veil,
      ),
      isTrue,
    );
    cache.paintVisible(ui.Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
    expect(cache.buildCount, built + 1, reason: 'новый блок (9, 9), остальные берутся из кеша');

    cache
      ..configure(
        scene: scene,
        progress: before.withCells(const <CellPosition>[CellPosition(5, 5)], done: false),
        veil: _veil,
      )
      ..paintVisible(ui.Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
    expect(cache.buildCount, built + 2, reason: 'снятая клетка — перестроен только блок (0, 0)');
  });

  test('опустевший блок выбрасывается из кеша', () {
    final GridScene scene = _scene();
    final CellProgress one = CellProgress(width: 200).withCells(const <CellPosition>[CellPosition(3, 3)], done: true);
    cache
      ..configure(scene: scene, progress: one, veil: _veil)
      ..paintVisible(ui.Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
    expect(cache.cachedBlocks, 1);
    cache.configure(scene: scene, progress: const CellProgress.none(), veil: _veil);
    expect(cache.cachedBlocks, 0);
  });

  test('другая вуаль или другая раскладка сбрасывают все блоки', () {
    final GridScene scene = _scene();
    final CellProgress progress = _filled(40, 40);
    cache
      ..configure(scene: scene, progress: progress, veil: _veil)
      ..paintVisible(ui.Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
    expect(cache.cachedBlocks, 9);
    expect(cache.configure(scene: scene, progress: progress, veil: const Color(0x80000000)), isTrue);
    expect(cache.cachedBlocks, 0);
    cache.paintVisible(ui.Canvas(ui.PictureRecorder()), Offset.zero & scene.size);
    expect(cache.configure(scene: _scene(columns: 100), progress: progress, veil: const Color(0x80000000)), isTrue);
    expect(cache.cachedBlocks, 0);
  });

  test('клетки за пределами схемы не рисуются', () async {
    final GridScene scene = _scene(columns: 10, rows: 10);
    final CellProgress progress = CellProgress(
      width: 200,
    ).withCells(const <CellPosition>[CellPosition(12, 3)], done: true);
    cache.configure(scene: scene, progress: progress, veil: const Color(0xFFFF0000));
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    cache.paintVisible(Canvas(recorder), Offset.zero & scene.size);
    final ui.Image image = await recorder.endRecording().toImage(
      scene.size.width.ceil() + 100,
      scene.size.height.ceil(),
    );
    final ByteData data = (await image.toByteData())!;
    expect(data.buffer.asUint8List().every((b) => b == 0), isTrue);
  });

  test('рисует вуаль ровно по отмеченным клеткам', () async {
    final GridScene scene = _scene(columns: 20, rows: 20);
    final CellProgress progress = CellProgress(
      width: 20,
    ).withCells(const <CellPosition>[CellPosition(2, 2), CellPosition(3, 2), CellPosition(4, 2)], done: true);
    cache.configure(scene: scene, progress: progress, veil: const Color(0xFFFF0000));
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    cache.paintVisible(Canvas(recorder), Offset.zero & scene.size);
    final ui.Image image = await recorder.endRecording().toImage(scene.size.width.ceil(), scene.size.height.ceil());
    final ByteData data = (await image.toByteData())!;
    int alphaAt(Offset p) => data.getUint8(((p.dy.round() * image.width + p.dx.round()) * 4) + 3);
    expect(alphaAt(scene.cellRect(const CellPosition(2, 2)).center), greaterThan(0));
    expect(alphaAt(scene.cellRect(const CellPosition(4, 2)).center), greaterThan(0));
    expect(alphaAt(scene.cellRect(const CellPosition(5, 2)).center), 0);
    expect(alphaAt(scene.cellRect(const CellPosition(3, 3)).center), 0);
  });
}
