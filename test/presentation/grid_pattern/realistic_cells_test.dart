import 'dart:ui';

import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/presentation/grid_pattern/grid_layer_cache.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/grid_pattern/realistic_cells.dart';
import 'package:flutter_test/flutter_test.dart';

import 'grid_fixtures.dart';

final class _Cloth implements CellMetrics {
  const _Cloth();

  @override
  double get widthMm => 2;

  @override
  double get heightMm => 2;
}

void main() {
  test('материал по размерам ячейки', () {
    expect(RealisticMaterial.forMetrics(BeadSize.delica11), RealisticMaterial.cylinderBead);
    expect(RealisticMaterial.forMetrics(BeadSize.rocaille11), RealisticMaterial.roundBead);
    expect(RealisticMaterial.forMetrics(const _Cloth()), RealisticMaterial.crossStitch);
    expect(RealisticMaterial.cylinderBead.isBead, isTrue);
    expect(RealisticMaterial.crossStitch.isBead, isFalse);
  });

  test('реалистичный вид меняет слой ячеек, но не подсветку рядов', () {
    const GridViewOptions flat = GridViewOptions();
    const GridViewOptions realistic = GridViewOptions(realistic: true);
    expect(flat.sameBaseLayer(realistic), isFalse);
    expect(realistic.sameBaseLayer(const GridViewOptions(realistic: true, currentRow: 2)), isTrue);
  });

  for (final (String, GridGeometry, CellMetrics) c in <(String, GridGeometry, CellMetrics)>[
    ('станок', const GridGeometry.rectangular(), BeadSize.delica11),
    ('пейот', const GridGeometry.peyote(), BeadSize.rocaille11),
    ('кирпич', const GridGeometry.brick(), BeadSize.delica11),
    ('вышивка', const GridGeometry.rectangular(), const _Cloth()),
  ]) {
    test('слой «как будет выглядеть»: ${c.$1} строится и берётся из кеша', () {
      final GridLayerCache cache = GridLayerCache();
      addTearDown(cache.dispose);
      final GridScene scene = GridScene(geometry: c.$2, metrics: c.$3, columns: 12, rows: 10);
      cache.configure(
        grid: sampleGrid(),
        palette: samplePalette(),
        scene: scene,
        options: const GridViewOptions(realistic: true),
        style: const GridPaintStyle(
          line: Color(0x40000000),
          boldLine: Color(0xCC000000),
          emptyCell: Color(0x14000000),
          unknown: Color(0xFFC7C7CC),
        ),
      );
      final PictureRecorder recorder = PictureRecorder();
      cache.paintVisible(Canvas(recorder), Offset.zero & scene.size);
      recorder.endRecording().dispose();
      final int built = cache.buildCount;
      expect(built, greaterThan(0));
      final PictureRecorder again = PictureRecorder();
      cache.paintVisible(Canvas(again), Offset.zero & scene.size);
      again.endRecording().dispose();
      expect(cache.buildCount, built);
    });
  }

  test('смена вида или цветов подложки сбрасывает слой', () {
    final GridLayerCache cache = GridLayerCache();
    addTearDown(cache.dispose);
    final GridScene scene = GridScene(
      geometry: const GridGeometry.rectangular(),
      metrics: BeadSize.delica11,
      columns: 12,
      rows: 10,
    );
    void configure(GridViewOptions options, GridPaintStyle style) => cache.configure(
      grid: sampleGrid(),
      palette: samplePalette(),
      scene: scene,
      options: options,
      style: style,
    );
    void paint() {
      final PictureRecorder recorder = PictureRecorder();
      cache.paintVisible(Canvas(recorder), Offset.zero & scene.size);
      recorder.endRecording().dispose();
    }

    const GridPaintStyle style = GridPaintStyle(
      line: Color(0x40000000),
      boldLine: Color(0xCC000000),
      emptyCell: Color(0x14000000),
      unknown: Color(0xFFC7C7CC),
    );
    configure(const GridViewOptions(), style);
    paint();
    expect(cache.cachedBlocks, greaterThan(0));
    configure(const GridViewOptions(realistic: true), style);
    expect(cache.cachedBlocks, 0);
    paint();
    configure(
      const GridViewOptions(realistic: true),
      const GridPaintStyle(
        line: Color(0x40000000),
        boldLine: Color(0xCC000000),
        emptyCell: Color(0x14000000),
        unknown: Color(0xFFC7C7CC),
        realistic: RealisticColors(surface: Color(0xFF000000), thread: Color(0xFF111111)),
      ),
    );
    expect(cache.cachedBlocks, 0);
  });
}
