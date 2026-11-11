import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('вид клетки вышивки по умолчанию зависит от знаков', () {
    expect(const GridViewOptions().effectiveStitchStyle, StitchStyle.color);
    expect(const GridViewOptions(showSymbols: true).effectiveStitchStyle, StitchStyle.colorAndSymbol);
    expect(
      const GridViewOptions(showSymbols: true, stitchStyle: StitchStyle.crosses).effectiveStitchStyle,
      StitchStyle.crosses,
    );
  });

  test('слой ячеек пересобирается при смене вида и подсветки, но не отметок, центра и скрытых слоёв', () {
    const GridViewOptions base = GridViewOptions();
    expect(base.sameBaseLayer(const GridViewOptions(stitchStyle: StitchStyle.crosses)), isFalse);
    expect(base.sameBaseLayer(const GridViewOptions(highlightColor: 2)), isFalse);
    expect(base.sameBaseLayer(const GridViewOptions(showCenter: true)), isTrue);
    expect(base.sameBaseLayer(const GridViewOptions(hiddenLayers: <StitchLayerKind>{StitchLayerKind.lines})), isTrue);
    expect(base.sameBaseLayer(GridViewOptions(doneCells: <CellPosition>{const CellPosition(0, 0)})), isTrue);
  });

  test('настройки равны по значению', () {
    expect(
      GridViewOptions(doneCells: <CellPosition>{const CellPosition(1, 2)}, highlightColor: 3),
      GridViewOptions(doneCells: <CellPosition>{const CellPosition(1, 2)}, highlightColor: 3),
    );
    expect(const GridViewOptions(showCenter: true), isNot(const GridViewOptions()));
  });
}
