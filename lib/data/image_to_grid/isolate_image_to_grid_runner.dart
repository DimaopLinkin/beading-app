import 'dart:isolate';

import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_runner.dart';

/// Запускает конвейер в отдельном изоляте: вход и результат копируются между изолятами целиком.
final class IsolateImageToGridRunner implements ImageToGridRunner {
  const IsolateImageToGridRunner({this.pipeline = const ImageToGridPipeline()});

  final ImageToGridPipeline pipeline;

  @override
  Future<GeneratedPattern> run(ImageToGridRequest request) => Isolate.run(() => pipeline.run(request));
}
