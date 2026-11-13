import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/data/sharing/zip_biser_codec.dart';
import 'package:beading/domain/sharing/biser/biser_json.dart';
import 'package:beading/domain/sharing/biser/biser_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/biser_samples.dart';

void main() {
  const ZipBiserCodec codec = ZipBiserCodec();

  test('encode → decode: тот же набор, файл — настоящий zip с manifest.json и images/', () {
    for (int seed = 0; seed < 10; seed++) {
      final BiserBundle bundle = randomBundle(seed, projects: 3);
      final Uint8List bytes = codec.encode(bundle).valueOrNull!;
      expect(codec.decode(bytes).valueOrNull, bundle, reason: 'seed $seed');
      final Archive archive = ZipDecoder().decodeBytes(bytes);
      expect(archive.files.map((f) => f.name), contains('manifest.json'));
      expect(archive.files.where((f) => f.name.startsWith('images/')), hasLength(bundle.files.length));
    }
  });

  test('не zip и пустые байты — ValidationFailure', () {
    expect(codec.decode(Uint8List.fromList(<int>[1, 2, 3])).failureOrNull, isA<ValidationFailure>());
    expect(codec.decode(Uint8List(0)).failureOrNull, isA<ValidationFailure>());
  });

  test('zip без манифеста', () {
    final Archive archive = Archive()..addFile(ArchiveFile('другое.txt', 1, <int>[65]));
    final Uint8List bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    expect(codec.decode(bytes).failureOrNull, isA<ValidationFailure>());
  });

  test('манифест новой версии — понятная ошибка', () {
    final String manifest = jsonEncode(<String, Object?>{
      'format': BiserJson.formatName,
      'version': biserFormatVersion + 1,
      'kind': 'project',
      'exportedAt': 0,
      'appVersion': '9',
      'projects': <Object?>[],
    });
    final List<int> data = utf8.encode(manifest);
    final Archive archive = Archive()..addFile(ArchiveFile(BiserJson.manifestPath, data.length, data));
    final Result<BiserBundle> result = codec.decode(Uint8List.fromList(ZipEncoder().encode(archive)));
    expect((result.failureOrNull! as ValidationFailure).message, contains('более новой версией'));
  });
}
