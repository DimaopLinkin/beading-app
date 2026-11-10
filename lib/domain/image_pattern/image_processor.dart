import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:equatable/equatable.dart';

/// Готовая страница: PNG и его размер.
class ProcessedImage extends Equatable {
  const ProcessedImage({required this.png, required this.width, required this.height});

  final Uint8List png;
  final int width;
  final int height;

  @override
  List<Object?> get props => <Object?>[png, width, height];
}

/// Приводит любую поддерживаемую картинку (в том числе HEIC с iPhone) к PNG, поворачивает и обрезает.
abstract interface class ImageProcessor {
  /// Сначала поворот на [quarterTurns]×90° по часовой стрелке, потом обрезка по [crop].
  Future<Result<ProcessedImage>> process(Uint8List bytes, {int quarterTurns = 0, CropRect crop = CropRect.full});
}
