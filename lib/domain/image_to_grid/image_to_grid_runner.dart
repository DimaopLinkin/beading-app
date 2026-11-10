import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';

/// Запуск конвейера вне главного потока: расчёт большой картинки не должен подвешивать интерфейс.
/// Реализация лежит в слое data.
abstract interface class ImageToGridRunner {
  Future<GeneratedPattern> run(ImageToGridRequest request);
}
