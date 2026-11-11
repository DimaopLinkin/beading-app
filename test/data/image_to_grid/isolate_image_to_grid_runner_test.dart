import 'package:beading/data/image_to_grid/isolate_image_to_grid_runner.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
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

    final GeneratedPattern viaIsolate = await IsolateImageToGridRunner().run(request);
    final GeneratedPattern direct = const ImageToGridPipeline().run(request);

    expect(viaIsolate.grid, direct.grid);
    expect(viaIsolate.palette, direct.palette);
    expect(viaIsolate.palette.first, isA<PaletteEntry>().having((e) => e.rgb, 'rgb', isA<Rgb>()));
  });

  group('сессия', () {
    ImageToGridRequest pixelRequest(SourceImage image, {int maxColors = 4, bool draft = false}) => ImageToGridRequest(
      image: image,
      geometry: const GridGeometry.rectangular(),
      metrics: const FakeCellMetrics(1, 1),
      columns: 4,
      rows: 4,
      maxColors: maxColors,
      paletteBuilder: const AccentPaletteBuilder(),
      labeler: const VotingCellLabeler(),
      draft: draft,
    );

    final SourceImage image = blockImage(<List<int>>[
      <int>[0xFF0000, 0x00FF00, 0x0000FF, 0xFFFFFF],
      <int>[0x0000FF, 0xFFFFFF, 0xFF0000, 0x00FF00],
      <int>[0xFF0000, 0x00FF00, 0x0000FF, 0xFFFFFF],
      <int>[0x0000FF, 0xFFFFFF, 0xFF0000, 0x00FF00],
    ], block: 12);

    test('повторный запрос с той же картинкой берёт стадии из кеша изолята и даёт тот же результат', () async {
      final IsolateImageToGridRunner runner = IsolateImageToGridRunner();
      addTearDown(runner.release);
      final GeneratedPattern first = await runner.run(pixelRequest(image));
      final GeneratedPattern again = await runner.run(pixelRequest(image));
      expect(again.grid, first.grid);
      expect(again.palette, first.palette);
      expect(again.stats!.stageTimes['sample'], Duration.zero);
      expect(again.stats!.stageTimes['palette'], Duration.zero);
      final GeneratedPattern fewer = await runner.run(pixelRequest(image, maxColors: 2));
      expect(fewer.grid, const ImageToGridPipeline().run(pixelRequest(image, maxColors: 2)).grid);
    });

    test('черновик считается и отдаёт схему того же размера', () async {
      final IsolateImageToGridRunner runner = IsolateImageToGridRunner();
      addTearDown(runner.release);
      final GeneratedPattern draft = await runner.run(pixelRequest(image, draft: true));
      final GeneratedPattern full = await runner.run(pixelRequest(image));
      expect(draft.grid.width, full.grid.width);
      expect(draft.grid.height, full.grid.height);
    });

    test('новая картинка заменяет прежнюю, после release сессия начинается заново', () async {
      final IsolateImageToGridRunner runner = IsolateImageToGridRunner();
      addTearDown(runner.release);
      await runner.run(pixelRequest(image));
      final SourceImage other = blockImage(<List<int>>[
        <int>[0x000000, 0x111111, 0x222222, 0x333333],
        <int>[0x444444, 0x555555, 0x666666, 0x777777],
        <int>[0x888888, 0x999999, 0xAAAAAA, 0xBBBBBB],
        <int>[0xCCCCCC, 0xDDDDDD, 0xEEEEEE, 0xFFFFFF],
      ], block: 12);
      final GeneratedPattern changed = await runner.run(pixelRequest(other));
      expect(changed.grid, const ImageToGridPipeline().run(pixelRequest(other)).grid);
      await runner.release();
      final GeneratedPattern restarted = await runner.run(pixelRequest(image));
      expect(restarted.grid, const ImageToGridPipeline().run(pixelRequest(image)).grid);
    });

    test('release во время запуска не зависает: запрос получает ошибку, следующий работает', () async {
      final IsolateImageToGridRunner runner = IsolateImageToGridRunner();
      addTearDown(runner.release);
      final Future<GeneratedPattern> pending = runner.run(pixelRequest(image));
      final Future<void> expectation = expectLater(pending, throwsStateError);
      await runner.release();
      await expectation;
      final GeneratedPattern next = await runner.run(pixelRequest(image));
      expect(next.grid, const ImageToGridPipeline().run(pixelRequest(image)).grid);
    });
  });
}
