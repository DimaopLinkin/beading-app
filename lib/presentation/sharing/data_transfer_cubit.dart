import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:beading/domain/sharing/biser/export_projects.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/domain/sharing/file_sharer.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:beading/domain/stitch_import/import_oxs.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Файл, который ждёт решения пользовательницы: что в нём и его байты.
final class PendingImport extends Equatable {
  const PendingImport({required this.preview, required this.bytes});

  final BiserPreview preview;
  final Uint8List bytes;

  @override
  List<Object?> get props => <Object?>[preview, bytes];
}

final class DataTransferState extends Equatable {
  const DataTransferState({this.busy = false, this.pending, this.imported, this.failure});

  /// Идёт экспорт, разбор или импорт.
  final bool busy;

  /// Файл разобран, ждём подтверждения.
  final PendingImport? pending;

  /// Итог последнего импорта; экран показывает его один раз.
  final ImportResult? imported;

  /// Ошибка последнего действия; экран показывает её один раз.
  final Failure? failure;

  @override
  List<Object?> get props => <Object?>[busy, pending, imported, failure];
}

/// Обмен файлами `.biser`: поделиться проектом, резервная копия, импорт и восстановление.
/// Один на приложение: файл может прийти из системы в любой момент, поверх любого экрана.
class DataTransferCubit extends Cubit<DataTransferState> {
  DataTransferCubit({
    required ExportProjects export,
    required ImportBiser import,
    required FileSharer sharer,
    required BiserFilePicker picker,
    ImportOxs? importOxs,
  }) : _export = export,
       _importOxs = importOxs,
       _import = import,
       _sharer = sharer,
       _picker = picker,
       super(const DataTransferState());

  final ExportProjects _export;
  final ImportBiser _import;
  final FileSharer _sharer;
  final BiserFilePicker _picker;
  final ImportOxs? _importOxs;

  /// «Поделиться файлом проекта».
  Future<void> shareProject(String projectId, {ShareOrigin? origin}) =>
      _share(() => _export.project(projectId), origin);

  /// Резервная копия всей библиотеки.
  Future<void> backup({ShareOrigin? origin}) => _share(_export.backup, origin);

  Future<void> _share(Future<Result<BiserExport>> Function() build, ShareOrigin? origin) async {
    if (state.busy) {
      return;
    }
    emit(const DataTransferState(busy: true));
    final Result<BiserExport> built = await build();
    Failure? failure = built.failureOrNull;
    if (failure == null) {
      final BiserExport file = built.valueOrNull!;
      failure = (await _sharer.shareFile(bytes: file.bytes, fileName: file.fileName, origin: origin)).failureOrNull;
    }
    if (!isClosed) {
      emit(DataTransferState(failure: failure));
    }
  }

  /// «Восстановить из файла»: выбор файла в «Файлах», затем обзор.
  Future<void> pickAndPreview() async {
    if (state.busy) {
      return;
    }
    emit(const DataTransferState(busy: true));
    final Result<BiserFile?> picked = await _picker.pick();
    if (picked case Err<BiserFile?>(:final Failure failure)) {
      emit(DataTransferState(failure: failure));
      return;
    }
    final BiserFile? file = picked.valueOrNull;
    if (file == null) {
      emit(const DataTransferState());
      return;
    }
    await _route(file);
  }

  /// Файл, который система открыла в приложении.
  Future<void> openFile(BiserFile file) async {
    if (state.busy || state.pending != null) {
      return;
    }
    emit(const DataTransferState(busy: true));
    await _route(file);
  }

  /// Файл не удалось прочитать ещё до разбора.
  void reportFailure(Failure failure) => emit(DataTransferState(failure: failure));

  /// Схемы `.oxs` (T42) создаются сразу, без обзора: в файле одна схема и конфликтов id нет; остальное — `.biser`.
  Future<void> _route(BiserFile file) async {
    final ImportOxs? oxs = _importOxs;
    if (oxs == null || !file.name.toLowerCase().endsWith('.oxs')) {
      return _preview(file.bytes);
    }
    final Result<ImportResult> result = await oxs(file.bytes, fileName: file.name);
    if (isClosed) {
      return;
    }
    emit(
      switch (result) {
        Err<ImportResult>(:final Failure failure) => DataTransferState(failure: failure),
        Success<ImportResult>(:final ImportResult value) => DataTransferState(imported: value),
      },
    );
  }

  Future<void> _preview(Uint8List bytes) async {
    final Result<BiserPreview> preview = await _import.preview(bytes);
    if (isClosed) {
      return;
    }
    emit(
      switch (preview) {
        Err<BiserPreview>(:final Failure failure) => DataTransferState(failure: failure),
        Success<BiserPreview>(:final BiserPreview value) when value.items.isEmpty => const DataTransferState(
          failure: ValidationFailure('В файле нет проектов'),
        ),
        Success<BiserPreview>(:final BiserPreview value) => DataTransferState(
          pending: PendingImport(preview: value, bytes: bytes),
        ),
      },
    );
  }

  /// Подтверждение импорта; [conflicts] — что делать с проектами, которые уже есть.
  Future<void> confirmImport(ConflictChoice conflicts) async {
    final PendingImport? pending = state.pending;
    if (pending == null || state.busy) {
      return;
    }
    emit(const DataTransferState(busy: true));
    final Result<ImportResult> result = await _import(pending.bytes, defaultChoice: conflicts);
    if (isClosed) {
      return;
    }
    emit(
      switch (result) {
        Err<ImportResult>(:final Failure failure) => DataTransferState(failure: failure),
        Success<ImportResult>(:final ImportResult value) => DataTransferState(imported: value),
      },
    );
  }

  /// Отказ от импорта или «понятно» после сообщения.
  void dismiss() => emit(const DataTransferState());
}
