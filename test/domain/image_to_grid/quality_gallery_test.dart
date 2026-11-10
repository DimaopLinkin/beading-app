import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../gallery/gallery_support.dart';

/// Регрессия качества генератора: метрики каждого варианта на каждой фикстуре не хуже базы `baseline.json`.
void main() {
  late List<GalleryRun> runs;
  late Map<String, Map<String, num>> baseline;

  setUpAll(() {
    baseline = readBaseline();
  });

  testWidgets('метрики не хуже базы: одиночных клеток не больше +20 %, ΔE не выше +1,0', (tester) async {
    runs = (await tester.runAsync(() async => runGallery(await loadPhotos(), loadBeadCatalog())))!;
    final List<String> problems = <String>[];
    for (final GalleryRun run in runs) {
      final Map<String, num>? base = baseline[run.key];
      if (base == null) {
        problems.add(
          '${run.key}: нет в baseline.json (GALLERY_UPDATE_BASELINE=1 flutter test --tags gallery test/gallery/)',
        );
        continue;
      }
      if (run.stats.singleCells > base['singles']! * 1.2) {
        problems.add('${run.key}: одиночных клеток ${run.stats.singleCells}, в базе ${base['singles']}');
      }
      if (run.stats.meanDeltaE > base['deltaE']! + 1.0) {
        problems.add(
          '${run.key}: ΔE ${run.stats.meanDeltaE.toStringAsFixed(2)}, в базе ${base['deltaE']}',
        );
      }
    }
    expect(problems, isEmpty);
    expect(
      baseline.keys.toSet().difference(runs.map((r) => r.key).toSet()),
      isEmpty,
      reason: 'лишние ключи в базе',
    );
  });

  test('у каждой фикстуры есть строка с лицензией в README', () {
    final String readme = File('$photosDir/README.md').readAsStringSync();
    final List<String> files = <String>[
      for (final FileSystemEntity e in Directory(photosDir).listSync())
        if (e is File && e.path.endsWith('.png')) e.uri.pathSegments.last,
    ];
    expect(files, isNotEmpty);
    for (final String file in files) {
      expect(
        RegExp('`$file`[^\\n]*\\|[^|\\n]+\\|[^|\\n]*\\S[^|\\n]*\\|\\s*\$', multiLine: true).hasMatch(readme),
        isTrue,
        reason: 'нет лицензии для $file',
      );
    }
  });
}
