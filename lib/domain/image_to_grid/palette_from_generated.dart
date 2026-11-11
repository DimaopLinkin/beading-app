import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_to_grid/generated_pattern.dart';
import 'package:beading/domain/image_to_grid/palette_entry.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';

/// Бренд у цветов вне каталога (свободная палитра): код — их `#RRGGBB`. В каталоге такой позиции нет, поэтому
/// расчёт материалов относится к ним как к пользовательским.
const String customColorBrand = 'custom';

/// Палитра схемы из результата конвейера: каждому цвету свой символ, позиции каталога сохраняются ссылкой.
Result<PaletteSnapshot> paletteFromGenerated(GeneratedPattern pattern) {
  PaletteSnapshot palette = PaletteSnapshot.empty();
  for (final PaletteEntry entry in pattern.palette) {
    final PatternColor color = switch (entry.catalog) {
      final catalog? when entry.blendPartner != null => PatternColor.blend(
        name: '${catalog.name} + ${entry.blendPartner!.name}',
        parts: <BlendPart>[
          BlendPart(ref: catalog.ref, rgb: catalog.rgb),
          BlendPart(ref: entry.blendPartner!.ref, rgb: entry.blendPartner!.rgb),
        ],
      ),
      final catalog? => PatternColor(
        rgb: catalog.rgb,
        name: catalog.name,
        components: <CatalogRef>[catalog.ref],
        finish: catalog.finish,
      ),
      null => PatternColor(
        rgb: entry.rgb,
        name: entry.rgb.hex,
        components: <CatalogRef>[CatalogRef(brand: customColorBrand, code: entry.rgb.hex)],
      ),
    };
    final Result<PaletteEdit> added = palette.add(color);
    switch (added) {
      case Success<PaletteEdit>(:final PaletteEdit value):
        palette = value.palette;
      case Err<PaletteEdit>(:final Failure failure):
        return Err<PaletteSnapshot>(failure);
    }
  }
  return Success<PaletteSnapshot>(palette);
}
