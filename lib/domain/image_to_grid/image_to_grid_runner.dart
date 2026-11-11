import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_request.dart';

/// Запуск конвейера вне главного потока: расчёт большой картинки не должен подвешивать интерфейс.
/// Реализация лежит в слое data.
///
/// Запускатель помнит прошлые расчёты (T58): повторный запрос с той же картинкой не пересчитывает стадии, на которые
/// изменённые параметры не влияют. Картинку для этого нужно передавать тем же объектом.
abstract interface class ImageToGridRunner {
  Future<GeneratedPattern> run(ImageToGridRequest request);

  /// Забывает картинку и кеш и освобождает ресурсы; следующий [run] начнёт сессию заново.
  Future<void> release();
}
