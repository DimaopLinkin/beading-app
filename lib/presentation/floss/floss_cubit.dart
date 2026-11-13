import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/floss_stock/floss_shortage.dart';
import 'package:beading/domain/floss_stock/floss_stock_entry.dart';
import 'package:beading/domain/floss_stock/floss_stock_repository.dart';
import 'package:beading/domain/materials/floss_estimate.dart';
import 'package:beading/domain/materials/use_cases/load_project_floss.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/printing/use_cases/export_pattern_pdf.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/projects/project_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum FlossStatus { loading, ready, failure }

class FlossState extends Equatable {
  const FlossState({
    this.status = FlossStatus.loading,
    this.projectName = '',
    this.estimate,
    this.failure,
    this.withReserve = false,
    this.remainingOnly = false,
    this.stock = const <FlossStockEntry>[],
    this.writeFailure,
  });

  final FlossStatus status;
  final String projectName;
  final FlossEstimate? estimate;
  final Failure? failure;

  /// Показывать мотки с запасом (в списках, итоге и тексте «Поделиться»).
  final bool withReserve;

  /// Считать только невышитые крестики («что нужно на оставшуюся работу»).
  final bool remainingOnly;

  /// Запас мулине: общий для всех проектов.
  final List<FlossStockEntry> stock;

  /// Ошибка последней записи запаса; сбрасывается следующей успешной.
  final Failure? writeFailure;

  bool get isEmpty =>
      estimate != null && estimate!.lines.isEmpty && estimate!.beads.isEmpty && estimate!.purchases.isEmpty;

  /// Хватает ли запаса: по ниткам расчёта; `null`, пока расчёта нет.
  FlossShortage? get shortage =>
      estimate == null ? null : FlossShortage.compute(estimate!.purchases, stock, withReserve: withReserve);

  FlossState copyWith({
    bool? withReserve,
    bool? remainingOnly,
    List<FlossStockEntry>? stock,
    Failure? writeFailure,
    bool clearWriteFailure = false,
  }) => FlossState(
    status: status,
    projectName: projectName,
    estimate: estimate,
    failure: failure,
    withReserve: withReserve ?? this.withReserve,
    remainingOnly: remainingOnly ?? this.remainingOnly,
    stock: stock ?? this.stock,
    writeFailure: clearWriteFailure ? null : (writeFailure ?? this.writeFailure),
  );

  @override
  List<Object?> get props => <Object?>[
    status,
    projectName,
    estimate,
    failure,
    withReserve,
    remainingOnly,
    stock,
    writeFailure,
  ];
}

/// Расход мулине проекта-вышивки: нитки по цветам, список покупок и канва; сверка с запасом ниток и что докупить.
class FlossCubit extends Cubit<FlossState> {
  FlossCubit({
    required this.projectId,
    required LoadProjectFloss loadFloss,
    required ExportPatternPdf exportPdf,
    required ProjectRepository projects,
    required FlossStockRepository stock,
  }) : _loadFloss = loadFloss,
       _exportPdf = exportPdf,
       _projects = projects,
       _stock = stock,
       super(const FlossState()) {
    _stockSub = _stock.watchAll().listen((entries) {
      if (!isClosed) emit(state.copyWith(stock: entries));
    });
  }

  final String projectId;
  final LoadProjectFloss _loadFloss;
  final ExportPatternPdf _exportPdf;
  final ProjectRepository _projects;
  final FlossStockRepository _stock;
  StreamSubscription<List<FlossStockEntry>>? _stockSub;

  /// PDF схемы для печати (T76); состояние экрана не меняет.
  Future<Result<PatternPdf>> exportPdf() => _exportPdf(projectId);

  Future<void> load() async {
    final FlossState before = state;
    emit(FlossState(withReserve: before.withReserve, remainingOnly: before.remainingOnly, stock: before.stock));
    final Result<Project> project = await _projects.get(projectId);
    if (isClosed) return;
    if (project case Err<Project>(:final Failure failure)) {
      emit(
        FlossState(
          status: FlossStatus.failure,
          failure: failure,
          withReserve: before.withReserve,
          remainingOnly: before.remainingOnly,
          stock: state.stock,
        ),
      );
      return;
    }
    final Result<FlossEstimate> estimate = await _loadFloss(projectId, remainingOnly: before.remainingOnly);
    if (isClosed) return;
    final String name = project.valueOrNull?.name ?? '';
    switch (estimate) {
      case Success<FlossEstimate>(:final FlossEstimate value):
        emit(
          FlossState(
            status: FlossStatus.ready,
            projectName: name,
            estimate: value,
            withReserve: before.withReserve,
            remainingOnly: before.remainingOnly,
            stock: state.stock,
          ),
        );
      case Err<FlossEstimate>(:final Failure failure):
        emit(
          FlossState(
            status: FlossStatus.failure,
            projectName: name,
            failure: failure,
            withReserve: before.withReserve,
            remainingOnly: before.remainingOnly,
            stock: state.stock,
          ),
        );
    }
  }

  void setWithReserve({required bool value}) => emit(state.copyWith(withReserve: value));

  /// Переключает «вся схема» / «осталось вышить»; пересчитывает расход.
  Future<void> setRemainingOnly({required bool value}) async {
    if (value == state.remainingOnly) return;
    emit(state.copyWith(remainingOnly: value));
    await load();
  }

  /// Записывает, сколько мотков [ref] осталось ([skeins] ≤ 0 — убрать из запаса).
  Future<void> setStock(CatalogRef ref, double skeins) async {
    final Result<void> result = await _stock.setSkeins(ref, skeins);
    if (isClosed) return;
    switch (result) {
      case Success<void>():
        emit(state.copyWith(clearWriteFailure: true));
      case Err<void>(:final Failure failure):
        emit(state.copyWith(writeFailure: failure));
    }
  }

  @override
  Future<void> close() {
    unawaited(_stockSub?.cancel());
    return super.close();
  }
}
