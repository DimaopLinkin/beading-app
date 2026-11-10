import 'package:beading/data/image_to_grid/isolate_image_to_grid_runner.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/grid/fake_cell_metrics.dart';
import '../../domain/image_to_grid/image_fixtures.dart';

void main() {
  test('изолят возвращает тот же результат, что и прямой запуск', () async {
    final ImageToGridRequest request = ImageToGridRequest(
      image: blockImage(<List<int>>[
        <int>[0xFF0000, 0x00FF00],
        <int>[0x0000FF, 0xFFFFFF],
      ], block: 6),
      geometry: const GridGeometry.rectangular(),
      metrics: const FakeCellMetrics(1, 1),
      columns: 2,
      rows: 2,
      maxColors: 4,
      dither: true,
      seed: 5,
    );

    final GeneratedPattern viaIsolate = await const IsolateImageToGridRunner().run(request);
    final GeneratedPattern direct = const ImageToGridPipeline().run(request);

    expect(viaIsolate.grid, direct.grid);
    expect(viaIsolate.palette, direct.palette);
    expect(viaIsolate.palette.first, isA<PaletteEntry>().having((e) => e.rgb, 'rgb', isA<Rgb>()));
  });
}
