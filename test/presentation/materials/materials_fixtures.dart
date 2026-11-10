import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/materials/bead_estimate.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';

/// Расход, выписанный вручную: три цвета Delica 11/0 (0,005 г), запас 10%.
///
/// 1240 шт = 6,2 г (с запасом 1364 шт = 6,82 г); 36 шт = 0,18 г (40 шт = 0,2 г); 4 шт = 0,02 г (5 шт = 0,025 г).
BeadEstimate handWrittenEstimate() => BeadEstimate(
  beadSize: BeadSize.delica11,
  reserve: 0.1,
  lines: <BeadMaterialLine>[
    BeadMaterialLine(
      colorIndex: 1,
      color: PatternColor(
        rgb: const Rgb(200, 10, 20),
        name: 'Красный',
        components: const <CatalogRef>[CatalogRef(brand: 'Miyuki Delica', code: 'DB0010')],
        symbol: 'A',
      ),
      pieces: 1240,
      piecesWithReserve: 1364,
      grams: 6.2,
      gramsWithReserve: 6.82,
    ),
    BeadMaterialLine(
      colorIndex: 2,
      color: PatternColor(
        rgb: const Rgb(30, 40, 50),
        name: 'Смесь',
        components: const <CatalogRef>[
          CatalogRef(brand: 'DMC', code: '310'),
          CatalogRef(brand: 'DMC', code: '666'),
        ],
        symbol: 'B',
      ),
      pieces: 36,
      piecesWithReserve: 40,
      grams: 0.18,
      gramsWithReserve: 0.2,
    ),
    BeadMaterialLine(
      colorIndex: 3,
      color: PatternColor(
        rgb: const Rgb(250, 250, 250),
        name: 'Белый',
        components: const <CatalogRef>[CatalogRef(brand: 'Toho', code: '41')],
      ),
      pieces: 4,
      piecesWithReserve: 5,
      grams: 0.02,
      gramsWithReserve: 0.025,
    ),
  ],
);
