import 'package:beading/app/composition/core_module.dart';
import 'package:beading/data/sync/blob_externalizer.dart';
import 'package:beading/data/sync/drift_sync_store.dart';
import 'package:beading/data/sync/record_transport.dart';
import 'package:beading/data/sync/supabase_sync_remote.dart';
import 'package:beading/data/sync/supabase_sync_session.dart';
import 'package:beading/data/sync/sync_entity_mapper.dart';
import 'package:beading/domain/sync/sync_engine.dart';
import 'package:beading/domain/sync/sync_session.dart';
import 'package:beading/presentation/sync/sync_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Синхронизация между устройствами (ADR-0006). Есть, только если сборка знает адрес и ключ Supabase.
final class SyncModule {
  SyncModule({required CoreModule core, required SupabaseClient client}) : _core = core, _client = client;

  final CoreModule _core;
  final SupabaseClient _client;

  late final SyncSession session = SupabaseSyncSession(_client.auth);

  late final DriftSyncStore _store = DriftSyncStore(
    ctx: SyncDbContext(db: _core.database, ids: _core.ids),
  );

  late final SyncEngine engine = SyncEngine(
    store: _store,
    schema: _store.schema,
    remote: SupabaseSyncRemote(
      records: SupabaseRecordTransport(_client),
      externalizer: BlobExternalizer(blobs: SupabaseBlobTransport(_client), files: _core.fileStore),
    ),
  );

  /// Один на приложение: держит таймер и последний статус.
  late final SyncCubit controller = SyncCubit(
    session: session,
    engine: engine,
    clock: _core.clock,
    isNetworkError: isNetworkError,
  );

  Future<void> dispose() => controller.close();
}
