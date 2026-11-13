import 'dart:math' as math;

import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/image_to_grid/cell_neighbors.dart';
import 'package:beading/domain/image_to_grid/face_guide.dart';
import 'package:beading/domain/image_to_grid/face_size_advisor.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/palette/lab.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../gallery/gallery_support.dart';

/// Приёмка T54 на портрете галереи при размере схемы, где лицо не меньше порога в 20 клеток (на 40 клетках лицо
/// шире 9 клеток, там мастер предупреждает и предлагает обрезать).
void main() {
  testWidgets('портрет 120 клеток: тёмные клетки в глазах, кожа — не больше 4 цветов и без одиночных клеток', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final GalleryPhoto portrait = (await loadPhotos()).firstWhere((p) => p.name == 'portrait');
      expect(const FaceSizeAdvisor().advise(galleryFaces[portrait.image]!, columns: 40), isNotNull);
      expect(const FaceSizeAdvisor().advise(galleryFaces[portrait.image]!, columns: 120), isNull);
      final GalleryVariant faces = galleryVariants.firstWhere((v) => v.id == 't54-faces');
      for (final Technique technique in <Technique>[Technique.loom, Technique.peyote]) {
        final GalleryTarget target = GalleryTarget(
          id: '${technique.name}-120',
          technique: technique,
          metrics: BeadSize.delica11,
          columns: 120,
          maxColors: 10,
        );
        final GalleryRun run = GalleryRun(
          photo: portrait,
          target: target,
          variant: faces,
          pattern: const ImageToGridPipeline().run(faces.build(portrait.image, target, const [])),
        );
        final FaceCells cells = faceCellsOf(run)!;
        final int columns = run.pattern.grid.width;
        final int rows = run.pattern.grid.height;
        int at(int i) => run.pattern.grid.at(i % columns, i ~/ columns);
        double lightness(int i) => Lab.fromRgb(run.pattern.palette[at(i) - 1].rgb).l;

        expect(cells.eyes, hasLength(2), reason: run.key);
        for (final List<int> eye in cells.eyes) {
          expect(eye.map(lightness).reduce(math.min), lessThan(45), reason: '${run.key}: тёмная клетка в глазу');
        }
        final CellNeighbors neighbors = CellNeighbors.of(geometry: target.geometry, columns: columns, rows: rows);
        // Кожа без края лица: на границе с волосами и фоном другие цвета законны.
        bool interior(int i) {
          for (int n = 0; n < neighbors.count(i); n++) {
            final int other = neighbors.at(i, n);
            if (!cells.isSkin(other) && !cells.isFeature(other)) return false;
          }
          return neighbors.count(i) >= 4;
        }

        final Set<int> skinColors = <int>{};
        int singles = 0;
        for (int i = 0; i < cells.skin.length; i++) {
          if (!cells.isSkin(i)) continue;
          skinColors.add(at(i));
          if (!interior(i)) continue;
          bool same = false;
          for (int n = 0; n < neighbors.count(i); n++) {
            if (at(neighbors.at(i, n)) == at(i)) same = true;
          }
          if (!same) singles++;
        }
        expect(skinColors.length, lessThanOrEqualTo(4), reason: '${run.key}: цветов кожи');
        expect(singles, 0, reason: '${run.key}: одиночных клеток кожи');
      }
    });
  });
}
