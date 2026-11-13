import 'dart:isolate';

import 'package:beading/data/image_to_grid/isolate_image_to_grid_runner.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/image_to_grid/cell_labeler.dart';
import 'package:beading/domain/image_to_grid/face_guide.dart';
import 'package:beading/domain/image_to_grid/face_palette_builder.dart';
import 'package:beading/domain/image_to_grid/face_step.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';
import 'package:beading/domain/image_to_grid/palette_builder.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/image_to_grid/pattern_step.dart';
import 'package:beading/domain/image_to_grid/source_image.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/grid/fake_cell_metrics.dart';
import '../../domain/image_to_grid/image_fixtures.dart';

/// Шаг, убивающий изолят посреди расчёта (изолят «умер вне задания»).
final class _KillIsolateStep implements PatternStep {
  const _KillIsolateStep();

  @override
  GeneratedPattern apply(GeneratedPattern pattern, PatternStepContext context) {
    Isolate.current.kill(priority: Isolate.immediate);
    return pattern;
  }
}

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
    ImageToGridRequest pixelRequest(
      SourceImage image, {
      int maxColors = 4,
      bool draft = false,
      List<PatternStep> steps = const <PatternStep>[],
    }) => ImageToGridRequest(
      image: image,
      geometry: const GridGeometry.rectangular(),
      metrics: const FakeCellMetrics(1, 1),
      columns: 4,
      rows: 4,
      maxColors: maxColors,
      paletteBuilder: const AccentPaletteBuilder(),
      labeler: const VotingCellLabeler(),
      draft: draft,
      steps: steps,
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

    test('лица передаются один раз: новый FaceGuide с теми же масками берёт стадии из кеша', () async {
      final ImageMaskSet masks = ImageMaskSet(
        width: 4,
        height: 4,
        faces: const <DetectedFace>[
          DetectedFace(bounds: NormalizedRect(left: 0.1, top: 0.1, right: 0.9, bottom: 0.9)),
        ],
      );
      ImageToGridRequest withFaces({int maxColors = 4}) => ImageToGridRequest(
        image: image,
        geometry: const GridGeometry.rectangular(),
        metrics: const FakeCellMetrics(1, 1),
        columns: 4,
        rows: 4,
        maxColors: maxColors,
        paletteBuilder: const FaceAwarePaletteBuilder(),
        labeler: const VotingCellLabeler(),
        faces: FaceGuide(masks),
        steps: const <PatternStep>[FaceFeatureStep()],
      );
      final IsolateImageToGridRunner runner = IsolateImageToGridRunner();
      addTearDown(runner.release);
      final GeneratedPattern first = await runner.run(withFaces());
      final GeneratedPattern again = await runner.run(withFaces());
      expect(again.grid, first.grid);
      expect(again.stats!.stageTimes['sample'], Duration.zero);
      expect(again.stats!.stageTimes['palette'], Duration.zero);
      expect(first.grid, const ImageToGridPipeline().run(withFaces()).grid);
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

    test('после гибели изолята следующий запрос с той же картинкой считается по ней, а не по заглушке', () async {
      final IsolateImageToGridRunner runner = IsolateImageToGridRunner();
      addTearDown(runner.release);
      final ImageToGridRequest dying = pixelRequest(image, steps: const <PatternStep>[_KillIsolateStep()]);
      await expectLater(runner.run(dying), throwsStateError);
      final GeneratedPattern next = await runner.run(pixelRequest(image));
      final GeneratedPattern expected = const ImageToGridPipeline().run(pixelRequest(image));
      expect(next.grid, expected.grid);
      expect(next.palette, expected.palette);
      expect(next.palette.length, greaterThan(1));
    });

    test('пока считается запрос, ждущий заменяется новым: устаревшие расчёты не копятся', () async {
      final IsolateImageToGridRunner runner = IsolateImageToGridRunner();
      addTearDown(runner.release);
      final Future<GeneratedPattern> running = runner.run(pixelRequest(image));
      final Future<GeneratedPattern> stale = runner.run(pixelRequest(image, maxColors: 2));
      final Future<GeneratedPattern> latest = runner.run(pixelRequest(image, maxColors: 3));
      final Future<void> staleExpectation = expectLater(stale, throwsA(isA<RunSuperseded>()));

      expect((await running).grid, const ImageToGridPipeline().run(pixelRequest(image)).grid);
      await staleExpectation;
      expect((await latest).grid, const ImageToGridPipeline().run(pixelRequest(image, maxColors: 3)).grid);
    });

    test('заменённый запрос, нёсший картинку, не лишает следующий пикселей', () async {
      final IsolateImageToGridRunner runner = IsolateImageToGridRunner();
      addTearDown(runner.release);
      final SourceImage other = blockImage(<List<int>>[
        <int>[0x000000, 0xFFFFFF],
        <int>[0xFFFFFF, 0x000000],
      ], block: 4);
      final Future<GeneratedPattern> running = runner.run(pixelRequest(image));
      // Эта картинка ушла бы в изолят вместе с заменяемым запросом.
      final Future<GeneratedPattern> carrier = runner.run(pixelRequest(other));
      final Future<void> carrierExpectation = expectLater(carrier, throwsA(isA<RunSuperseded>()));
      final Future<GeneratedPattern> next = runner.run(pixelRequest(other, maxColors: 3));
      await running;
      await carrierExpectation;
      expect((await next).grid, const ImageToGridPipeline().run(pixelRequest(other, maxColors: 3)).grid);
    });
  });
}
