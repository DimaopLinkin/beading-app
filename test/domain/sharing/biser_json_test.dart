import 'dart:convert';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/sharing/biser/biser_json.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/biser_samples.dart';

void main() {
  Result<BiserBundle> parse(Object? manifest, Map<String, Uint8List> files) =>
      BiserJson.decode(manifest is String ? manifest : jsonEncode(manifest), files);

  Map<String, Object?> manifestOf(BiserBundle bundle) => jsonDecode(BiserJson.encode(bundle)) as Map<String, Object?>;

  String messageOf(Result<BiserBundle> result) => (result.failureOrNull! as ValidationFailure).message;

  test('round-trip: encode → decode даёт то же самое (30 случайных наборов)', () {
    for (int seed = 0; seed < 30; seed++) {
      final BiserBundle original = randomBundle(seed, projects: 1 + seed % 5);
      final Result<BiserBundle> decoded = BiserJson.decode(BiserJson.encode(original), original.files);
      expect(decoded.valueOrNull, original, reason: 'seed $seed');
    }
  });

  test('неизвестная (новая) версия формата — понятная ошибка', () {
    final Map<String, Object?> manifest = manifestOf(randomBundle(1))..['version'] = biserFormatVersion + 1;
    final Result<BiserBundle> result = parse(manifest, const <String, Uint8List>{});
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(messageOf(result), contains('более новой версией'));
  });

  test('чужой JSON, не JSON и мусор — ValidationFailure без исключений', () {
    expect(parse('не json', const <String, Uint8List>{}).failureOrNull, isA<ValidationFailure>());
    expect(
      parse(<String, Object?>{'format': 'other'}, const <String, Uint8List>{}).failureOrNull,
      isA<ValidationFailure>(),
    );
    expect(parse('[1,2]', const <String, Uint8List>{}).failureOrNull, isA<ValidationFailure>());
    expect(
      parse(<String, Object?>{'format': 'biser', 'version': 'x'}, const <String, Uint8List>{}).failureOrNull,
      isA<ValidationFailure>(),
    );
  });

  group('проверки содержимого', () {
    final BiserBundle grids = randomBundle(7, projects: 6);
    final BiserBundle withBook = _bundleWith(ContentKindForTest.image);

    Result<BiserBundle> mutate(BiserBundle source, void Function(Map<String, Object?> project) change) {
      final Map<String, Object?> manifest = manifestOf(source);
      change((manifest['projects']! as List<Object?>).first! as Map<String, Object?>);
      return parse(manifest, source.files);
    }

    test('цвет в сетке вне палитры', () {
      final BiserBundle gridBundle = _bundleWith(ContentKindForTest.grid);
      final Result<BiserBundle> result = mutate(gridBundle, (p) {
        ((p['grid']! as Map<String, Object?>)['palette']! as List<Object?>).clear();
      });
      expect(messageOf(result), contains('вне палитры'));
    });

    test('техника не подходит к ремеслу', () {
      final Result<BiserBundle> result = mutate(grids, (p) {
        p['craft'] = 'crossStitch';
        p['technique'] = 'loom';
      });
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('отмеченный ряд вне схемы', () {
      final BiserBundle gridBundle = _bundleWith(ContentKindForTest.grid);
      final Result<BiserBundle> result = mutate(gridBundle, (p) {
        ((p['grid']! as Map<String, Object?>)['progress']! as Map<String, Object?>)['completedRows'] = <int>[999];
      });
      expect(messageOf(result), contains('вне схемы'));
    });

    test('нет файла страницы в архиве', () {
      final Result<BiserBundle> result = parse(manifestOf(withBook), const <String, Uint8List>{});
      expect(messageOf(result), contains('нет файла страницы'));
    });

    test('страница — не PNG', () {
      final Map<String, Uint8List> files = <String, Uint8List>{
        for (final k in withBook.files.keys) k: Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8, 9]),
      };
      expect(messageOf(parse(manifestOf(withBook), files)), contains('не картинка PNG'));
    });

    test('сетка из base64-мусора', () {
      final BiserBundle gridBundle = _bundleWith(ContentKindForTest.grid);
      final Result<BiserBundle> result = mutate(
        gridBundle,
        (p) => (p['grid']! as Map<String, Object?>)['cells'] = '###',
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('неизвестный статус проекта', () {
      expect(mutate(grids, (p) => p['status'] = 'wat').failureOrNull, isA<ValidationFailure>());
    });

    test('обложка ссылается на несуществующую страницу', () {
      final Result<BiserBundle> result = mutate(withBook, (p) => p['coverPageId'] = 'нет-такой');
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('один проект дважды', () {
      final Map<String, Object?> manifest = manifestOf(grids);
      final List<Object?> list = manifest['projects']! as List<Object?>;
      list.add(list.first);
      expect(messageOf(parse(manifest, grids.files)), contains('дважды'));
    });

    test('id с «/» и «..» отвергаются: он попадал бы в путь файла', () {
      expect(
        mutate(withBook, (p) => (p['book']! as Map<String, Object?>)['id'] = 'x/../чужая').failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        mutate(withBook, (p) => (p['book']! as Map<String, Object?>)['id'] = '../x').failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(mutate(grids, (p) => p['id'] = 'a b').failureOrNull, isA<ValidationFailure>());
    });

    test('пустой id и нечисловое время', () {
      expect(mutate(grids, (p) => p['id'] = '').failureOrNull, isA<ValidationFailure>());
      expect(mutate(grids, (p) => p['lastWorkedAt'] = 'вчера').failureOrNull, isA<ValidationFailure>());
    });
  });
}

enum ContentKindForTest { grid, image }

/// Первый проект набора нужного вида (случайные наборы подбираем по seed).
BiserBundle _bundleWith(ContentKindForTest kind) {
  for (int seed = 0; seed < 200; seed++) {
    final BiserBundle bundle = randomBundle(seed, projects: 1);
    final BiserProject first = bundle.projects.first;
    if (kind == ContentKindForTest.grid && first.grid != null && first.progress!.completedRows.isNotEmpty) {
      return bundle;
    }
    if (kind == ContentKindForTest.image && first.book != null && first.coverPageId != null) {
      return bundle;
    }
  }
  throw StateError('нет подходящего набора');
}
