import 'package:beading/core/failure.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/grid/cell_metrics.dart';
import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/cell_metrics_codec.dart';
import 'package:beading/domain/grid_pattern/grid_geometry_codec.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:flutter_test/flutter_test.dart';

import '../grid/fake_cell_metrics.dart';

void main() {
  group('GridGeometryCodec', () {
    test('все геометрии записываются и читаются обратно', () {
      const List<GridGeometry> all = <GridGeometry>[
        GridGeometry.rectangular(),
        GridGeometry.peyote(),
        GridGeometry.peyote(drop: 3),
        GridGeometry.brick(),
      ];
      for (final GridGeometry geometry in all) {
        final StoredGeometry stored = GridGeometryCodec.encode(geometry);
        final GridGeometry back = GridGeometryCodec.decode(kind: stored.kind, drop: stored.drop).valueOrNull!;
        expect(GridGeometryCodec.encode(back), stored);
      }
    });

    test('имена видов зафиксированы', () {
      expect(GridGeometryCodec.encode(const GridGeometry.peyote(drop: 2)), (kind: 'peyote', drop: 2));
      expect(GridGeometryCodec.encode(const GridGeometry.rectangular()).kind, 'rectangular');
      expect(GridGeometryCodec.encode(const GridGeometry.brick()).kind, 'brick');
    });

    test('неизвестный вид и drop меньше 1 — ValidationFailure', () {
      expect(GridGeometryCodec.decode(kind: 'hex', drop: 1).failureOrNull, isA<ValidationFailure>());
      expect(GridGeometryCodec.decode(kind: 'peyote', drop: 0).failureOrNull, isA<ValidationFailure>());
    });
  });

  group('CellMetricsCodec: канва', () {
    test('канва записывается видом fabric и читается тем же объектом', () {
      final List<Fabric> all = <Fabric>[
        Fabric.create(kind: FabricKind.aida, count: 14).valueOrNull!,
        Fabric.create(kind: FabricKind.evenweave, count: 28, color: const Rgb(240, 230, 200)).valueOrNull!,
        Fabric.create(kind: FabricKind.linen, count: 32, overCount: 1).valueOrNull!,
      ];
      for (final Fabric fabric in all) {
        final String stored = CellMetricsCodec.encode(fabric).valueOrNull!;
        expect(CellMetricsCodec.decode(stored).valueOrNull, fabric);
      }
    });

    test('формат зафиксирован', () {
      final Fabric f = Fabric.create(kind: FabricKind.linen, count: 32, color: const Rgb(1, 2, 3)).valueOrNull!;
      expect(
        CellMetricsCodec.encode(f).valueOrNull,
        '{"kind":"fabric","fabric":"linen","count":32,"over":2,"color":"#010203"}',
      );
    });

    test('старые виды bead и custom читаются по-прежнему', () {
      expect(
        CellMetricsCodec.decode('{"kind":"bead","shape":"delica","size":"11/0"}').valueOrNull,
        BeadSize.delica11,
      );
      expect(
        CellMetricsCodec.decode('{"kind":"custom","widthMm":2,"heightMm":3}').valueOrNull,
        const CustomCellMetrics(widthMm: 2, heightMm: 3),
      );
    });

    test('неверная канва — ValidationFailure', () {
      for (final String bad in <String>[
        '{"kind":"fabric","fabric":"silk","count":14,"over":1,"color":"#ffffff"}',
        '{"kind":"fabric","fabric":"aida","count":99,"over":1,"color":"#ffffff"}',
        '{"kind":"fabric","fabric":"aida","count":14,"over":1,"color":"белый"}',
        '{"kind":"fabric","fabric":"aida","count":"14","over":1,"color":"#ffffff"}',
        '{"kind":"fabric","fabric":"aida","count":14,"over":2,"color":"#ffffff"}',
        '{"kind":"fabric","fabric":"aida","count":14.5,"over":1,"color":"#ffffff"}',
        '{"kind":"fabric","fabric":"aida","count":14}',
      ]) {
        expect(CellMetricsCodec.decode(bad).failureOrNull, isA<ValidationFailure>(), reason: bad);
      }
    });
  });

  group('CellMetricsCodec', () {
    test('каждый размер бусины записывается и читается тем же объектом', () {
      for (final BeadSize size in BeadSize.values) {
        final String stored = CellMetricsCodec.encode(size).valueOrNull!;
        expect(CellMetricsCodec.decode(stored).valueOrNull, size);
      }
    });

    test('произвольный размер сохраняется в миллиметрах', () {
      const CustomCellMetrics metrics = CustomCellMetrics(widthMm: 1.25, heightMm: 2.5);
      final String stored = CellMetricsCodec.encode(metrics).valueOrNull!;
      expect(CellMetricsCodec.decode(stored).valueOrNull, metrics);
    });

    test('неизвестная реализация CellMetrics не сохраняется', () {
      const CellMetrics fake = FakeCellMetrics(1, 1);
      expect(CellMetricsCodec.encode(fake).failureOrNull, isA<ValidationFailure>());
    });

    test('мусор, неизвестный вид и неверные числа — ValidationFailure', () {
      for (final String bad in <String>[
        'не json',
        '[]',
        '{"kind":"fabric"}',
        '{"kind":"bead","shape":"delica","size":"99/0"}',
        '{"kind":"custom","widthMm":0,"heightMm":1}',
        '{"kind":"custom","widthMm":"1","heightMm":1}',
      ]) {
        expect(CellMetricsCodec.decode(bad).failureOrNull, isA<ValidationFailure>(), reason: bad);
      }
    });
  });
}
