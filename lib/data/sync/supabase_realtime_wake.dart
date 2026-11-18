import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Будит синхронизацию, когда другое устройство записало в `sync_records` (ADR-0006).
/// Содержимое события не используется: это только повод сделать обычный цикл. Канал живёт, пока пользователь вошёл,
/// и при каждом (пере)подключении тоже будит, чтобы не пропустить то, что случилось в обрыве.
class SupabaseRealtimeWake {
  SupabaseRealtimeWake(this._client) {
    _auth = _client.auth.onAuthStateChange.listen((state) {
      if (state.session == null) {
        unawaited(_close());
      } else if (_channel == null) {
        _open();
      }
    });
    if (_client.auth.currentSession != null) {
      _open();
    }
  }

  final SupabaseClient _client;
  final StreamController<void> _wakes = StreamController<void>.broadcast();
  late final StreamSubscription<AuthState> _auth;
  RealtimeChannel? _channel;

  Stream<void> get wakes => _wakes.stream;

  void _open() {
    _channel = _client
        .channel('sync_records')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sync_records',
          callback: (_) => _wakes.add(null),
        )
        .subscribe((status, _) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            _wakes.add(null);
          }
        });
  }

  Future<void> _close() async {
    final RealtimeChannel? channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  Future<void> dispose() async {
    await _auth.cancel();
    await _close();
    await _wakes.close();
  }
}
