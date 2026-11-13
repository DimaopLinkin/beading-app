import 'dart:async';

import 'package:beading/core/failure.dart';
import 'package:beading/domain/sharing/biser/biser_file_source.dart';
import 'package:beading/domain/sharing/biser/import_biser.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/sharing/data_transfer_cubit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Показывает диалоги обмена файлами поверх любого экрана и передаёт в [DataTransferCubit] файлы,
/// которые система открыла в приложении. Диалоги выводятся в навигатор [navigatorKey].
class DataTransferHost extends StatefulWidget {
  const DataTransferHost({
    required this.cubit,
    required this.incoming,
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  final DataTransferCubit cubit;
  final IncomingBiserFiles incoming;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<DataTransferHost> createState() => _DataTransferHostState();
}

class _DataTransferHostState extends State<DataTransferHost> {
  StreamSubscription<Object?>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.incoming.files.listen((result) {
      result.fold(onSuccess: widget.cubit.openFile, onFailure: widget.cubit.reportFailure);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<DataTransferCubit, DataTransferState>(
    bloc: widget.cubit,
    listenWhen: (previous, current) =>
        (current.pending != null && previous.pending != current.pending) ||
        (current.imported != null && previous.imported != current.imported) ||
        (current.failure != null && previous.failure != current.failure),
    listener: (_, state) => unawaited(_show(state)),
    child: widget.child,
  );

  Future<void> _show(DataTransferState state) async {
    final BuildContext? context = widget.navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (state.pending != null) {
      await _confirm(context, l10n, state.pending!);
    } else if (state.imported != null) {
      final ImportResult result = state.imported!;
      await _message(context, l10n.importDoneTitle, l10n.importDoneBody(result.importedIds.length, result.skipped));
      widget.cubit.dismiss();
    } else if (state.failure != null) {
      await _message(context, l10n.actionFailedTitle, _failureText(l10n, state.failure!));
      widget.cubit.dismiss();
    }
  }

  /// Ошибки разбора файла содержат понятный текст; системные ошибки — общий.
  String _failureText(AppLocalizations l10n, Failure failure) =>
      failure is ValidationFailure ? failure.message : l10n.transferFailedGeneric;

  Future<void> _confirm(BuildContext context, AppLocalizations l10n, PendingImport pending) async {
    final int conflicts = pending.preview.conflictCount;
    final String names = pending.preview.items.map((i) => '«${i.name}»').take(5).join(', ');
    final int count = pending.preview.items.length;
    final ConflictChoice? choice = await showCupertinoModalPopup<ConflictChoice>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(l10n.importConfirmTitle(count)),
        message: Text(conflicts == 0 ? names : '$names\n${l10n.importConflictsNote(conflicts)}'),
        actions: <Widget>[
          CupertinoActionSheetAction(
            key: const ValueKey<String>('import-as-new'),
            onPressed: () => Navigator.of(sheetContext).pop(ConflictChoice.asNew),
            child: Text(conflicts == 0 ? l10n.importAction : l10n.importAsNew),
          ),
          if (conflicts > 0)
            CupertinoActionSheetAction(
              key: const ValueKey<String>('import-skip'),
              onPressed: () => Navigator.of(sheetContext).pop(ConflictChoice.skip),
              child: Text(l10n.importSkipExisting),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(l10n.cancel),
        ),
      ),
    );
    if (choice == null) {
      widget.cubit.dismiss();
    } else {
      await widget.cubit.confirmImport(choice);
    }
  }

  Future<void> _message(BuildContext context, String title, String body) => showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(AppLocalizations.of(dialogContext).ok),
        ),
      ],
    ),
  );
}
