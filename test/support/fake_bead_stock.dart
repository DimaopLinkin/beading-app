import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/bead_stock/bead_stock_entry.dart';
import 'package:beading/domain/bead_stock/bead_stock_repository.dart';
import 'package:beading/domain/palette/catalog_ref.dart';

/// Запас бисера в памяти.
class FakeBeadStockRepository implements BeadStockRepository {
  FakeBeadStockRepository({Map<CatalogRef, double> initial = const <CatalogRef, double>{}}) {
    _grams.addAll(initial);
  }

  final Map<CatalogRef, double> _grams = <CatalogRef, double>{};
  final StreamController<List<BeadStockEntry>> _changes = StreamController<List<BeadStockEntry>>.broadcast();

  Map<CatalogRef, double> get snapshot => Map<CatalogRef, double>.unmodifiable(_grams);

  final Map<CatalogRef, DateTime> _updated = <CatalogRef, DateTime>{};

  /// Записи, пришедшие через `merge`.
  final List<BeadStockEntry> merged = <BeadStockEntry>[];

  @override
  Future<Result<void>> merge(List<BeadStockEntry> incoming) async {
    merged.addAll(incoming);
    for (final BeadStockEntry e in incoming) {
      final DateTime? at = e.updatedAt;
      if (at == null || e.grams <= 0) continue;
      final DateTime? have = _updated[e.ref];
      if (have == null || at.isAfter(have)) {
        _grams[e.ref] = e.grams;
        _updated[e.ref] = at;
      }
    }
    _changes.add(_entries);
    return const Success<void>(null);
  }

  /// Если задано, `setGrams` вернёт эту ошибку.
  Failure? failNextWrite;

  List<BeadStockEntry> get _entries => <BeadStockEntry>[
    for (final MapEntry<CatalogRef, double> e in _grams.entries) BeadStockEntry(ref: e.key, grams: e.value),
  ];

  @override
  Stream<List<BeadStockEntry>> watchAll() {
    // ignore: close_sinks, закрывается отменой подписки
    late StreamController<List<BeadStockEntry>> controller;
    StreamSubscription<List<BeadStockEntry>>? inner;
    controller = StreamController<List<BeadStockEntry>>(
      onListen: () {
        controller.add(_entries);
        inner = _changes.stream.listen(controller.add);
      },
      onCancel: () => inner?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Result<List<BeadStockEntry>>> all() async => Success<List<BeadStockEntry>>(_entries);

  @override
  Future<Result<void>> setGrams(CatalogRef ref, double grams) async {
    final Failure? failure = failNextWrite;
    if (failure != null) {
      failNextWrite = null;
      return Err<void>(failure);
    }
    if (grams <= 0) {
      _grams.remove(ref);
    } else {
      _grams[ref] = grams;
    }
    _changes.add(_entries);
    return const Success<void>(null);
  }
}
