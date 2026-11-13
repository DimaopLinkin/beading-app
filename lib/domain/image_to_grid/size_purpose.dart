import 'package:beading/domain/image_to_grid/image_to_grid_settings.dart';
import 'package:beading/domain/projects/craft.dart';

/// Размер по назначению (T61): «браслет», «панно», «картина» в бисере; у вышивки те же три ступени в сантиметрах.
enum SizePurpose {
  small(beadColumns: 24, stitchCm: 10),
  medium(beadColumns: 60, stitchCm: 25),
  large(beadColumns: 100, stitchCm: 40)
  ;

  const SizePurpose({required this.beadColumns, required this.stitchCm});

  /// Ширина в бусинах: узкая полоса браслета, панно, картина (с лицом читается от 60–100 столбцов).
  final int beadColumns;

  /// Ширина готовой вышивки, см (ориентир — Настя вышивает крупно: 20–30 см на аиде 14 и 18).
  final double stitchCm;

  /// Ширина схемы в клетках для текущих настроек: бисер — сразу столбцы, вышивка — сантиметры через канву.
  int columnsFor(ImageToGridSettings settings) {
    final int raw = settings.craft == Craft.crossStitch ? settings.fabric.cellsForCm(stitchCm) : beadColumns;
    return raw.clamp(ImageToGridSettings.minColumns, ImageToGridSettings.maxColumnsOf(settings.craft));
  }
}
