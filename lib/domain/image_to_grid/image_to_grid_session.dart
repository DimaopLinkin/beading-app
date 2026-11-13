import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_pipeline.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';

/// Долгоживущий запуск конвейера для живого предпросмотра (ADR-0004, п. 7, T58).
///
/// Помнит результаты стадий и по новому запросу пересчитывает только то, что зависит от изменившегося:
/// ползунок очистки трогает стадии 4–5, число цветов — палитру и всё после неё, новая картинка или размер — всё.
/// Результат всегда тот же, что у разового [ImageToGridPipeline.run]. Картинки сравниваются по тождеству: чтобы кеш
/// сработал, передавайте в запросах один и тот же объект [ImageToGridRequest.image].
///
/// Черновики ([ImageToGridRequest.draft]) и полные расчёты живут в отдельных кешах: движение ползунка не сбрасывает
/// полный расчёт, и наоборот.
final class ImageToGridSession {
  ImageToGridSession({this.pipeline = const ImageToGridPipeline()});

  final ImageToGridPipeline pipeline;
  final PixelStageCache _full = PixelStageCache();
  final PixelStageCache _draft = PixelStageCache();

  GeneratedPattern run(ImageToGridRequest request) => pipeline.run(request, cache: request.draft ? _draft : _full);
}
