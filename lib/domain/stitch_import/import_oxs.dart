import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/grid_pattern/use_cases/create_grid_pattern.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/domain/stitch/stitch_layers_codec.dart';
import 'package:beading/domain/stitch_import/oxs_converter.dart';
import 'package:beading/domain/stitch_import/oxs_pattern.dart';

/// Импорт схемы вышивки из `.oxs`: создаёт проект «вышивка крестиком» со схемой, палитрой, слоями и канвой.
class ImportOxs {
  const ImportOxs({
    required OxsDecoder decoder,
    required CreateGridPattern createPattern,
    OxsConverter converter = const OxsConverter(),
  }) : _decoder = decoder,
       _create = createPattern,
       _converter = converter;

  final OxsDecoder _decoder;
  final CreateGridPattern _create;
  final OxsConverter _converter;

  /// [fileName] — запасное название проекта, если в файле его нет.
  Future<Result<ImportResult>> call(Uint8List bytes, {required String fileName}) async {
    final Result<OxsPattern> decoded = _decoder.decode(bytes);
    if (decoded case Err<OxsPattern>(:final Failure failure)) {
      return Err<ImportResult>(failure);
    }
    final Result<OxsConversion> converted = _converter.convert(decoded.valueOrNull!);
    if (converted case Err<OxsConversion>(:final Failure failure)) {
      return Err<ImportResult>(failure);
    }
    final OxsConversion c = converted.valueOrNull!;
    final Result<CreatedGridPattern> created = await _create(
      name: c.name.isEmpty ? _baseName(fileName) : c.name,
      metrics: c.fabric,
      width: c.grid.width,
      height: c.grid.height,
      craft: Craft.crossStitch,
      technique: Technique.defaultFor(Craft.crossStitch),
      grid: c.grid,
      palette: c.palette,
      layers: c.layers.isEmpty && c.layers.colorSpecs.isEmpty ? null : StitchLayersCodec.toBlob(c.layers),
    );
    return switch (created) {
      Success<CreatedGridPattern>(:final CreatedGridPattern value) => Success<ImportResult>(
        ImportResult(importedIds: <String>[value.project.id], skipped: 0),
      ),
      Err<CreatedGridPattern>(:final Failure failure) => Err<ImportResult>(failure),
    };
  }

  static String _baseName(String fileName) {
    final String name = fileName.replaceFirst(RegExp(r'\.oxs$', caseSensitive: false), '').trim();
    return name.isEmpty ? 'Схема' : name;
  }
}
