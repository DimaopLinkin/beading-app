import 'package:beading/domain/sync/sync_engine.dart';
import 'package:beading/domain/sync/sync_session.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/sync/sync_cubit.dart';
import 'package:beading/presentation/sync/sync_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/sync/sync_fakes.dart';
import '../../support/fake_clock.dart';

class _Session implements SyncSession {
  @override
  String? userId;

  @override
  String? get email => userId == null ? null : 'masha@example.com';

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (password.length < 12) throw const SyncAuthException(SyncAuthFailure.invalidCredentials);
    userId = 'u1';
  }

  @override
  Future<void> signOut() async => userId = null;
}

void main() {
  testWidgets('вход, статус и выход', (tester) async {
    final SyncCubit cubit = SyncCubit(
      session: _Session(),
      engine: SyncEngine(store: FakeStore(), remote: FakeRemote(), schema: testSchema()),
      clock: FakeClock(DateTime(2026, 11, 13, 9, 5)),
      isNetworkError: (_) => false,
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<SyncCubit>.value(value: cubit, child: const SyncScreen()),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey<String>('sync-email')), 'masha@example.com');
    await tester.enterText(find.byKey(const ValueKey<String>('sync-password')), 'short');
    await tester.tap(find.byKey(const ValueKey<String>('sync-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('Неверная почта или пароль'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey<String>('sync-password')), 'long-enough-pass');
    await tester.tap(find.byKey(const ValueKey<String>('sync-sign-in')));
    await tester.pumpAndSettle();
    expect(find.text('masha@example.com'), findsOneWidget);
    expect(find.text('Обновлено в 09:05'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('sync-sign-out')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('sync-sign-in')), findsOneWidget);
  });
}
