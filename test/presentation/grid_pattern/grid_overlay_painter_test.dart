import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid/reading_order.dart';
import 'package:beading/presentation/grid_pattern/grid_overlay_painter.dart';
import 'package:beading/presentation/grid_pattern/grid_scene.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ByteData?> _render(GridScene scene, GridOverlayPainter painter) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Size size = scene.size + const Offset(80, 80);
  final Canvas canvas = Canvas(recorder)..translate(40, 40);
  painter.paint(canvas, scene.size);
  final ui.Image image = await recorder.endRecording().toImage(size.width.ceil(), size.height.ceil());
  return image.toByteData();
}

int _alpha(ByteData data, int width, Offset p) => data.getUint8(((p.dy.round() * width + p.dx.round()) * 4) + 3);

void main() {
  const RowRingTokens ring = RowRingTokens(inner: Color(0xFF151316), outer: Color(0xFFFFFFFF));

  for (final MapEntry<String, GridGeometry> geometry in <String, GridGeometry>{
    'rectangular': const GridGeometry.rectangular(),
    'peyote': const GridGeometry.peyote(),
    'brick': const GridGeometry.brick(),
  }.entries) {
    testWidgets('кольцо ряда (${geometry.key}) не закрывает бусины ряда, но обводит его', (tester) async {
      final GridScene scene = GridScene(geometry: geometry.value, metrics: BeadSize.delica11, columns: 6, rows: 5);
      final GridOverlayPainter painter = GridOverlayPainter(
        scene: scene,
        options: const GridViewOptions(currentRow: 2, markCurrentRowBeads: false),
        veil: const Color(0x00000000),
        ring: ring,
      );
      await tester.runAsync(() async {
        final ByteData data = (await _render(scene, painter))!;
        final int width = (scene.size.width + 80).ceil();
        for (int column = 0; column < 6; column++) {
          final Offset center = scene.cellRect(CellPosition(column, 2)).center + const Offset(40, 40);
          expect(_alpha(data, width, center), 0, reason: 'центр ячейки $column закрашен кольцом');
        }
        // Снаружи ряда над ячейкой 0 кольцо есть.
        final Rect first = scene.cellRect(const CellPosition(0, 2));
        expect(_alpha(data, width, first.topCenter + const Offset(40, 38)), greaterThan(0));
      });
    });
  }

  group('по порядку плетения', () {
    const Color veil = Color(0xFF00FF00);

    GridOverlayPainter painter(GridScene scene, GridViewOptions options) =>
        GridOverlayPainter(scene: scene, options: options, veil: veil, ring: ring);

    Offset center(GridScene scene, int column, int row) =>
        scene.cellRect(CellPosition(column, row)).center + const Offset(40, 40);

    testWidgets('станок с началом снизу: ряд плетения 0 — нижний ряд сетки, пройденный ряд 1 — выше него', (
      tester,
    ) async {
      final GridScene scene = GridScene(
        geometry: const GridGeometry.rectangular(),
        metrics: BeadSize.delica11,
        columns: 4,
        rows: 5,
      );
      final ReadingOrder order = ReadingOrder.of(
        const GridGeometry.rectangular(),
        columns: 4,
        rows: 5,
        start: ReadingStart.bottomLeft,
      );
      await tester.runAsync(() async {
        final ByteData data = (await _render(
          scene,
          painter(
            scene,
            GridViewOptions(order: order, currentRow: 1, doneRows: const <int>{0}, markCurrentRowBeads: false),
          ),
        ))!;
        final int width = (scene.size.width + 80).ceil();
        // Ряд плетения 0 — нижний ряд сетки (4) — под вуалью, ряд плетения 1 (сетка 3) — обведён и чист.
        expect(_alpha(data, width, center(scene, 1, 4)), greaterThan(0));
        expect(_alpha(data, width, center(scene, 1, 3)), 0);
        expect(_alpha(data, width, center(scene, 1, 0)), 0);
      });
    });

    testWidgets('пейот: ряд плетения — столбец; вуаль и кольцо идут по столбцам', (tester) async {
      final GridScene scene = GridScene(
        geometry: const GridGeometry.peyote(),
        metrics: BeadSize.delica11,
        columns: 5,
        rows: 4,
      );
      final ReadingOrder order = ReadingOrder.of(const GridGeometry.peyote(), columns: 5, rows: 4);
      await tester.runAsync(() async {
        final ByteData data = (await _render(
          scene,
          painter(
            scene,
            GridViewOptions(order: order, currentRow: 2, doneRows: const <int>{0, 1}, markCurrentRowBeads: false),
          ),
        ))!;
        final int width = (scene.size.width + 80).ceil();
        // Ряды 0 и 1 — столбцы 0–2 (первый ряд объединяет два), текущий ряд 2 — столбец 3.
        expect(_alpha(data, width, center(scene, 0, 1)), greaterThan(0));
        expect(_alpha(data, width, center(scene, 1, 2)), greaterThan(0));
        expect(_alpha(data, width, center(scene, 2, 2)), greaterThan(0));
        expect(_alpha(data, width, center(scene, 3, 2)), 0);
        expect(_alpha(data, width, center(scene, 4, 2)), 0);
      });
    });

    testWidgets('метки бусин, невыложенные бусины пунктиром и текущая бусина рисуются; вне схемы — без падения', (
      tester,
    ) async {
      final GridScene scene = GridScene(
        geometry: const GridGeometry.brick(),
        metrics: BeadSize.delica11,
        columns: 4,
        rows: 3,
      );
      final ReadingOrder order = ReadingOrder.of(const GridGeometry.brick(), columns: 4, rows: 3);
      await tester.runAsync(() async {
        final ByteData data = (await _render(
          scene,
          painter(
            scene,
            GridViewOptions(
              order: order,
              currentRow: 1,
              doneRows: const <int>{0, 1, 99, -1},
              pendingCells: const <CellPosition>[CellPosition(2, 1), CellPosition(3, 1)],
              currentCell: (column: 2, row: 1),
            ),
          ),
        ))!;
        final int width = (scene.size.width + 80).ceil();
        // Невыложенная бусина затянута вуалью.
        expect(_alpha(data, width, center(scene, 3, 1)), greaterThan(0));
      });
      await tester.runAsync(() async {
        await _render(
          scene,
          painter(
            scene,
            GridViewOptions(order: order, currentRow: 99, currentCell: (column: 40, row: 1)),
          ),
        );
      });
    });

    test('shouldRepaint реагирует на порядок и невыложенные бусины', () {
      final GridScene scene = GridScene(
        geometry: const GridGeometry.rectangular(),
        metrics: BeadSize.delica11,
        columns: 3,
        rows: 3,
      );
      final ReadingOrder order = ReadingOrder.of(const GridGeometry.rectangular(), columns: 3, rows: 3);
      final GridOverlayPainter a = painter(scene, GridViewOptions(order: order));
      expect(a.shouldRepaint(painter(scene, GridViewOptions(order: order))), isFalse);
      expect(
        a.shouldRepaint(
          painter(scene, GridViewOptions(order: order, pendingCells: const <CellPosition>[CellPosition(0, 0)])),
        ),
        isTrue,
      );
      expect(
        a.shouldRepaint(
          painter(
            scene,
            GridViewOptions(
              order: ReadingOrder.of(
                const GridGeometry.rectangular(),
                columns: 3,
                rows: 3,
                start: ReadingStart.bottomLeft,
              ),
            ),
          ),
        ),
        isTrue,
      );
    });
  });
}
