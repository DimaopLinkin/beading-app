import 'dart:typed_data';
import 'dart:ui';

import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/cell_range.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/cell_progress.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:flutter/widgets.dart';

/// Кеш слоя «сделано»: `Picture` на каждый блок отметок [CellProgress] (16×16 клеток).
///
/// Раньше вуаль строилась заново на каждый кадр одним контуром из всех сделанных клеток и не отсекалась по окну: на
/// плотной вышивке с залитой областью это десятки тысяч прямоугольников на кадр. Теперь блок строится один раз,
/// только когда попал в окно, и перестраивается, только если изменились его собственные отметки. Подряд идущие
/// клетки ряда сливаются в один прямоугольник.
final class GridDoneLayerCache {
  final Map<int, Picture> _pictures = <int, Picture>{};

  /// Биты блоков, по которым построены [_pictures]: по ним находим изменившиеся блоки без пересчёта остальных.
  Map<int, Uint8List> _source = const <int, Uint8List>{};

  CellProgress _progress = const CellProgress.none();
  GridScene? _scene;
  Color? _veil;
  Color? _mark;

  /// Сколько блоков построено за всё время (для тестов и профилирования).
  int buildCount = 0;

  int get cachedBlocks => _pictures.length;

  /// Сообщает кешу, что рисовать. Возвращает `true`, если что-то изменилось и слой надо перерисовать. [mark] — цвет
  /// галочки на каждой сделанной клетке; `null` — без галочек (клетки на экране слишком мелкие).
  bool configure({required GridScene scene, required CellProgress progress, required Color veil, Color? mark}) {
    final GridScene? oldScene = _scene;
    final bool sameLayout = oldScene != null && oldScene.sameLayout(scene) && _veil == veil && _mark == mark;
    if (sameLayout && (identical(_progress, progress) || _progress == progress)) {
      return false;
    }
    _scene = scene;
    _veil = veil;
    _mark = mark;
    if (!sameLayout) {
      _dropAll();
    } else {
      final Map<int, Uint8List> next = progress.blocks;
      for (final int key in <int>{..._source.keys, ...next.keys}) {
        final Uint8List? before = _source[key];
        final Uint8List? after = next[key];
        if (identical(before, after) || (before != null && after != null && _sameBits(before, after))) {
          continue;
        }
        _pictures.remove(key)?.dispose();
      }
    }
    _progress = progress;
    _source = progress.blocks;
    return true;
  }

  static bool _sameBits(Uint8List a, Uint8List b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _dropAll() {
    for (final Picture picture in _pictures.values) {
      picture.dispose();
    }
    _pictures.clear();
  }

  void dispose() {
    _dropAll();
  }

  /// Рисует блоки с отметками, пересекающие [visible] (прямоугольник в сцене).
  void paintVisible(Canvas canvas, Rect visible) {
    final GridScene? scene = _scene;
    if (scene == null || _progress.isEmpty) {
      return;
    }
    final CellRange range = scene.visibleCells(visible);
    if (range.isEmpty) {
      return;
    }
    const int side = CellProgress.blockSide;
    for (int by = range.firstRow ~/ side; by <= range.lastRow ~/ side; by++) {
      for (int bx = range.firstColumn ~/ side; bx <= range.lastColumn ~/ side; bx++) {
        final int key = by * CellProgress.blockStride + bx;
        final Uint8List? bits = _source[key];
        if (bits == null) {
          continue;
        }
        canvas.drawPicture(_pictures[key] ??= _build(scene, bx, by, bits));
      }
    }
  }

  Picture _build(GridScene scene, int bx, int by, Uint8List bits) {
    buildCount++;
    const int side = CellProgress.blockSide;
    final bool plain = scene.geometry is RectangularGeometry;
    final Path path = Path();
    final Path ticks = Path();
    for (int dy = 0; dy < side; dy++) {
      final int row = by * side + dy;
      if (row >= scene.rows) {
        break;
      }
      int dx = 0;
      while (dx < side) {
        if (!_isSet(bits, dx, dy) || bx * side + dx >= scene.columns) {
          dx++;
          continue;
        }
        int end = dx;
        // На рядах-прямоугольниках подряд идущие клетки сливаются; на ступенчатых геометриях каждая клетка отдельно.
        while (plain && end + 1 < side && bx * side + end + 1 < scene.columns && _isSet(bits, end + 1, dy)) {
          end++;
        }
        final Rect first = scene.cellRect(CellPosition(bx * side + dx, row));
        path.addRect(end == dx ? first : first.expandToInclude(scene.cellRect(CellPosition(bx * side + end, row))));
        if (_mark != null) {
          for (int c = dx; c <= end; c++) {
            _addTick(ticks, scene.cellRect(CellPosition(bx * side + c, row)));
          }
        }
        dx = end + 1;
      }
    }
    final PictureRecorder recorder = PictureRecorder();
    final Canvas canvas = Canvas(recorder)..drawPath(path, Paint()..color = _veil!);
    final Color? mark = _mark;
    if (mark != null) {
      // Толщина галочки по меньшей стороне клетки: на экране она видна, пока клетка не мельче порога плоского вида.
      final Rect any = scene.cellRect(const CellPosition(0, 0));
      final double shortSide = any.width < any.height ? any.width : any.height;
      canvas.drawPath(
        ticks,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = shortSide * 0.13
          ..color = mark,
      );
    }
    return recorder.endRecording();
  }

  /// Галочка в клетке: короткий штрих вниз и длинный вверх.
  static void _addTick(Path path, Rect cell) {
    Offset at(double x, double y) => Offset(cell.left + cell.width * x, cell.top + cell.height * y);
    path
      ..moveTo(at(0.28, 0.54).dx, at(0.28, 0.54).dy)
      ..lineTo(at(0.44, 0.7).dx, at(0.44, 0.7).dy)
      ..lineTo(at(0.74, 0.32).dx, at(0.74, 0.32).dy);
  }

  static bool _isSet(Uint8List bits, int dx, int dy) {
    final int bit = dy * CellProgress.blockSide + dx;
    return bits[bit >> 3] & (1 << (bit & 7)) != 0;
  }
}

/// Слой «сделано» схемы вышивки: берёт из [GridDoneLayerCache] готовые `Picture` видимых блоков. Перерисовывается при
/// зуме и сдвиге ([TransformationController] в `repaint`), блоки не перестраивает.
class GridDonePainter extends CustomPainter {
  GridDonePainter({
    required this.cache,
    required this.controller,
    required this.viewportSize,
    required this.revision,
    this.wholeScene = false,
  }) : super(repaint: controller);

  final GridDoneLayerCache cache;
  final TransformationController controller;
  final Size viewportSize;

  /// Растёт при каждой смене данных слоя.
  final int revision;

  final bool wholeScene;

  @override
  void paint(Canvas canvas, Size size) {
    if (wholeScene) {
      cache.paintVisible(canvas, Offset.zero & size);
      return;
    }
    final Matrix4 inverse = Matrix4.copy(controller.value)..invert();
    final Rect visible = MatrixUtils.transformRect(inverse, Offset.zero & viewportSize).inflate(32);
    cache.paintVisible(canvas, visible);
  }

  @override
  bool shouldRepaint(GridDonePainter oldDelegate) =>
      oldDelegate.cache != cache ||
      oldDelegate.viewportSize != viewportSize ||
      oldDelegate.revision != revision ||
      oldDelegate.wholeScene != wholeScene;
}
