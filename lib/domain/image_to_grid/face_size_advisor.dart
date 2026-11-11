import 'dart:math' as math;

import 'package:beading/domain/image_to_grid/image_mask_set.dart';
import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:equatable/equatable.dart';

/// Совет мастеру: лицо на схеме слишком мелкое, чтобы получиться (T54).
final class FaceSizeAdvice extends Equatable {
  const FaceSizeAdvice({required this.faceCells, required this.neededColumns, this.cropRect});

  /// Ширина самого крупного лица в клетках схемы.
  final double faceCells;

  /// Сколько клеток в ширину нужно схеме, чтобы лицо заняло [FaceSizeAdvisor.minFaceCells]. `null`, если больше,
  /// чем позволяет сетка: тогда остаётся только обрезка.
  final int? neededColumns;

  /// Область фото вокруг лица (доли картинки, те же пропорции, что у фото), при которой лицо займёт нужное число
  /// клеток при нынешней ширине схемы. `null`, если и обрезка не помогает.
  final NormalizedRect? cropRect;

  @override
  List<Object?> get props => <Object?>[faceCells, neededColumns, cropRect];
}

/// Предупреждение «лицо слишком мелкое»: при ширине лица меньше [minFaceCells] клеток черты глаз и рта не
/// получаются (порог из исследования A08, уточняется на галерее).
final class FaceSizeAdvisor {
  const FaceSizeAdvisor({this.minFaceCells = 20, this.maxColumns = ImageToGridSettings.maxColumns});

  final int minFaceCells;
  final int maxColumns;

  /// Совет для схемы шириной [columns] клеток или `null`, если лиц нет либо самое крупное достаточно крупное.
  FaceSizeAdvice? advise(ImageMaskSet masks, {required int columns}) {
    if (masks.faces.isEmpty || columns < 1) return null;
    DetectedFace? largest;
    for (final DetectedFace face in masks.faces) {
      if (face.bounds.width <= 0) continue;
      if (largest == null || face.bounds.width > largest.bounds.width) largest = face;
    }
    if (largest == null) return null;
    final NormalizedRect face = largest.bounds;
    final double faceCells = face.width * columns;
    if (faceCells >= minFaceCells) return null;

    final int needed = (minFaceCells / face.width).ceil();
    return FaceSizeAdvice(
      faceCells: faceCells,
      neededColumns: needed <= maxColumns ? needed : null,
      cropRect: _crop(face, faceCells),
    );
  }

  /// Квадрат-в-пропорциях фото вокруг лица: доля ширины фото [share] не больше, чем нужно, чтобы лицо заняло [minFaceCells] клеток.
  NormalizedRect? _crop(NormalizedRect face, double faceCells) {
    final double share = faceCells / minFaceCells;
    // С запасом на волосы, лоб и подбородок лицо займёт не больше 60 % кадра: так обрезка выглядит как портрет.
    final double wanted = face.width / 0.6;
    final double width = math.min(share, math.min(1, wanted));
    if (width < face.width * 1.1) return null;
    final double cx = (face.left + face.right) / 2;
    final double cy = (face.top + face.bottom) / 2;
    final double left = (cx - width / 2).clamp(0, 1 - width);
    final double top = (cy - width / 2).clamp(0, 1 - width);
    return NormalizedRect(left: left, top: top, right: left + width, bottom: top + width);
  }
}
