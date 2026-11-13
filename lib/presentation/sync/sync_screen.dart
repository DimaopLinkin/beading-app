import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/sync/sync_cubit.dart';
import 'package:beading/presentation/sync/sync_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Экран «Синхронизация»: вход по почте и паролю, статус и ручной запуск.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  static const String routePath = '/settings/sync';

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.settingsSync)),
      child: SafeArea(
        child: BlocBuilder<SyncCubit, SyncState>(
          builder: (context, state) => ListView(
            children: <Widget>[
              if (!state.signedIn) ..._signedOut(context, l10n, state) else ..._signedIn(context, l10n, state),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _signedOut(BuildContext context, AppLocalizations l10n, SyncState state) {
    final SyncCubit cubit = context.read<SyncCubit>();
    return <Widget>[
      CupertinoListSection.insetGrouped(
        footer: Text(_problemText(l10n, state.problem) ?? l10n.syncSignedOutHint),
        children: <Widget>[
          CupertinoTextFormFieldRow(
            key: const ValueKey<String>('sync-email'),
            controller: _email,
            prefix: Text(l10n.syncEmail),
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            autofillHints: const <String>[AutofillHints.username],
          ),
          CupertinoTextFormFieldRow(
            key: const ValueKey<String>('sync-password'),
            controller: _password,
            prefix: Text(l10n.syncPassword),
            obscureText: true,
            autocorrect: false,
            autofillHints: const <String>[AutofillHints.password],
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: CupertinoButton.filled(
          key: const ValueKey<String>('sync-sign-in'),
          onPressed: state.busy ? null : () => cubit.signIn(email: _email.text, password: _password.text),
          child: state.busy ? const CupertinoActivityIndicator() : Text(l10n.syncSignIn),
        ),
      ),
    ];
  }

  List<Widget> _signedIn(BuildContext context, AppLocalizations l10n, SyncState state) {
    final SyncCubit cubit = context.read<SyncCubit>();
    final String? problem = _problemText(l10n, state.problem);
    return <Widget>[
      CupertinoListSection.insetGrouped(
        footer: problem == null ? null : Text(problem),
        children: <Widget>[
          CupertinoListTile.notched(title: Text(l10n.syncAccount), additionalInfo: Text(state.email ?? '')),
          CupertinoListTile.notched(
            key: const ValueKey<String>('sync-status'),
            title: Text(_status(l10n, state)),
            trailing: state.busy ? const CupertinoActivityIndicator() : null,
          ),
          CupertinoListTile.notched(
            key: const ValueKey<String>('sync-now'),
            title: Text(l10n.syncNow),
            onTap: state.busy ? null : cubit.syncNow,
          ),
        ],
      ),
      CupertinoListSection.insetGrouped(
        children: <Widget>[
          CupertinoListTile.notched(
            key: const ValueKey<String>('sync-sign-out'),
            title: Text(l10n.syncSignOut, style: const TextStyle(color: CupertinoColors.destructiveRed)),
            onTap: cubit.signOut,
          ),
        ],
      ),
    ];
  }

  String _status(AppLocalizations l10n, SyncState state) {
    if (state.busy) return l10n.syncBusy;
    final DateTime? at = state.lastSyncedAt;
    if (at == null) return l10n.syncNever;
    final String time = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return l10n.syncUpdatedAt(time);
  }

  String? _problemText(AppLocalizations l10n, SyncProblem? problem) => switch (problem) {
    null => null,
    SyncProblem.invalidCredentials => l10n.syncProblemInvalidCredentials,
    SyncProblem.offline => l10n.syncProblemOffline,
    SyncProblem.server => l10n.syncProblemServer,
    SyncProblem.ownerMismatch => l10n.syncProblemOwnerMismatch,
    SyncProblem.needsAppUpdate => l10n.syncProblemNeedsAppUpdate,
    SyncProblem.failed => l10n.syncProblemFailed,
  };
}
