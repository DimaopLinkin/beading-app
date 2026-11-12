import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/floss_stock/floss_stock_entry.dart';
import 'package:beading/domain/floss_stock/floss_stock_repository.dart';
import 'package:beading/domain/palette/catalog_ref.dart';

/// Запас мулине в памяти.
class FakeFlossStockRepository implements FlossStockRepository {
  FakeFlossStockRepository({Map<CatalogRef, double> initial = const <CatalogRef, double>{}}) {
    _skeins.addAll(initial);
  }

  final Map<CatalogRef, double> _skeins = <CatalogRef, double>{};
  final StreamController<List<FlossStockEntry>> _changes = StreamController<List<FlossStockEntry>>.broadcast();

  Map<CatalogRef, double> get snapshot => Map<CatalogRef, double>.unmodifiable(_skeins);

  final Map<CatalogRef, DateTime> _updated = <CatalogRef, DateTime>{};

  /// Записи, пришедшие через `merge`.
  final List<FlossStockEntry> merged = <FlossStockEntry>[];

  @override
  Future<Result<void>> merge(List<FlossStockEntry> incoming) async {
    merged.addAll(incoming);
    for (final FlossStockEntry e in incoming) {
      final DateTime? at = e.updatedAt;
      if (at == null || e.skeins <= 0) continue;
      final DateTime? have = _updated[e.ref];
      if (have == null || at.isAfter(have)) {
        _skeins[e.ref] = e.skeins;
        _updated[e.ref] = at;
      }
    }
    _changes.add(_entries);
    return const Success<void>(null);
  }

  /// Если задано, `setSkeins` вернёт эту ошибку.
  Failure? failNextWrite;

  List<FlossStockEntry> get _entries => <FlossStockEntry>[
    for (final MapEntry<CatalogRef, double> e in _skeins.entries) FlossStockEntry(ref: e.key, skeins: e.value),
  ];

  @override
  Stream<List<FlossStockEntry>> watchAll() {
    // ignore: close_sinks, закрывается отменой подписки
    late StreamController<List<FlossStockEntry>> controller;
    StreamSubscription<List<FlossStockEntry>>? inner;
    controller = StreamController<List<FlossStockEntry>>(
      onListen: () {
        controller.add(_entries);
        inner = _changes.stream.listen(controller.add);
      },
      onCancel: () => inner?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<Result<List<FlossStockEntry>>> all() async => Success<List<FlossStockEntry>>(_entries);

  @override
  Future<Result<void>> setSkeins(CatalogRef ref, double skeins) async {
    final Failure? failure = failNextWrite;
    if (failure != null) {
      failNextWrite = null;
      return Err<void>(failure);
    }
    if (skeins <= 0) {
      _skeins.remove(ref);
    } else {
      _skeins[ref] = skeins;
    }
    _changes.add(_entries);
    return const Success<void>(null);
  }
}
