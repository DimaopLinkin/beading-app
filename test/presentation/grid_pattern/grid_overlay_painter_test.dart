import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
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
}
