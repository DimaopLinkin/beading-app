import 'dart:convert';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_codec.dart';
import 'package:beading/domain/steps/step_template.dart';
import 'package:flutter/services.dart';

/// Встроенные шаблоны инструкций из `assets/step_templates/*.json` (ADR-0008).
///
/// Файл: `id`, `title`, `description`, `body` (документ [StepPatternCodec]) и необязательные `images`:
/// `{id, file, width, height}`, где `file` лежит рядом с json. Битый шаблон пропускается, остальные работают.
class AssetStepTemplateSource implements StepTemplateSource {
  AssetStepTemplateSource([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  static const String _prefix = 'assets/step_templates/';

  final AssetBundle _bundle;
  List<StepTemplate>? _cache;

  @override
  Future<Result<List<StepTemplate>>> all() async {
    try {
      return Success<List<StepTemplate>>(_cache ??= await _load());
    } on Object catch (error) {
      return Err<List<StepTemplate>>(StorageFailure('Не удалось прочитать шаблоны: $error'));
    }
  }

  @override
  Future<Result<StepTemplate>> get(String id) async {
    final Result<List<StepTemplate>> found = await all();
    if (found case Err<List<StepTemplate>>(:final Failure failure)) {
      return Err<StepTemplate>(failure);
    }
    for (final StepTemplate t in found.valueOrNull!) {
      if (t.id == id) {
        return Success<StepTemplate>(t);
      }
    }
    return Err<StepTemplate>(NotFoundFailure('Нет шаблона $id'));
  }

  Future<List<StepTemplate>> _load() async {
    final AssetManifest manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final List<String> files = manifest.listAssets().where((p) => p.startsWith(_prefix) && p.endsWith('.json')).toList()
      ..sort();
    final List<StepTemplate> out = <StepTemplate>[];
    for (final String path in files) {
      try {
        out.add(await parse(await _bundle.loadString(path), _readImage));
      } on Object {
        continue; // один испорченный шаблон не прячет остальные
      }
    }
    return out;
  }

  Future<Uint8List> _readImage(String file) async => (await _bundle.load('$_prefix$file')).buffer.asUint8List();

  /// Разбирает один файл шаблона. Бросает, если документ не проходит кодек.
  static Future<StepTemplate> parse(String json, Future<Uint8List> Function(String file) readImage) async {
    final Map<String, Object?> doc = jsonDecode(json) as Map<String, Object?>;
    final String id = doc['id']! as String;
    final Result<StepPattern> body = StepPatternCodec.decode(jsonEncode(doc['body']), id: id, projectId: '');
    if (body case Err<StepPattern>(:final Failure failure)) {
      throw FormatException(failure.message);
    }
    final StepPattern pattern = body.valueOrNull!;
    final List<StepTemplateImage> images = <StepTemplateImage>[];
    for (final Object? raw in (doc['images'] as List<Object?>?) ?? const <Object?>[]) {
      final Map<String, Object?> m = raw! as Map<String, Object?>;
      images.add(
        StepTemplateImage(
          id: m['id']! as String,
          png: await readImage(m['file']! as String),
          width: m['width']! as int,
          height: m['height']! as int,
        ),
      );
    }
    return StepTemplate(
      id: id,
      title: doc['title']! as String,
      description: (doc['description'] as String?) ?? '',
      palette: pattern.palette,
      sections: pattern.sections,
      images: images,
    );
  }
}
