import 'package:beading/domain/grid/cell_metrics.dart';

/// Фейковые размеры ячейки для тестов геометрии.
class FakeCellMetrics implements CellMetrics {
  const FakeCellMetrics(this.widthMm, this.heightMm);

  @override
  final double widthMm;

  @override
  final double heightMm;
}
