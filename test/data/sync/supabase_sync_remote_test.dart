import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beading/data/sync/blob_externalizer.dart';
import 'package:beading/data/sync/record_transport.dart';
import 'package:beading/data/sync/supabase_sync_remote.dart';
import 'package:beading/domain/sync/merge_policy.dart';
import 'package:beading/domain/sync/sync_record.dart';
import 'package:beading/domain/sync/sync_remote.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain/sync/sync_fakes.dart';
import '../../support/fake_image_pattern.dart';

/// Сервер `sync_records` в памяти с поведением триггера: устаревшая запись пропускается и в ответ не попадает.
class _FakeRecords implements RecordTransport {
  final Map<String, WireRow> rows = <String, WireRow>{};
  int _seq = 0;

  @override
  Future<List<WireRow>> select({required int cursor, required int limit}) async {
    final List<WireRow> after = rows.values.where((r) => (r['server_seq']! as int) > cursor).toList()
      ..sort((a, b) => (a['server_seq']! as int).compareTo(b['server_seq']! as int));
    return after.take(limit).toList();
  }

  @override
  Future<List<WireRow>> upsert(List<WireRow> incoming) async {
    final List<WireRow> accepted = <WireRow>[];
    for (final WireRow row in incoming) {
      final String key = '${row['entity']}/${row['sync_id']}';
      final WireRow? old = rows[key];
      if (old != null && !MergePolicy.isNewer(_rec(row), _rec(old))) {
        continue;
      }
      final WireRow stored = <String, Object?>{...row, 'server_seq': ++_seq};
      rows[key] = stored;
      accepted.add(<String, Object?>{'entity': row['entity'], 'sync_id': row['sync_id'], 'server_seq': _seq});
    }
    return accepted;
  }

  SyncRecord _rec(WireRow r) => SyncRecord(
    entity: r['entity']! as String,
    syncId: r['sync_id']! as String,
    updatedAt: r['updated_at']! as int,
    deviceId: r['device_id']! as String,
  );
}

class _FakeBlobs implements BlobTransport {
  final Map<String, Uint8List> objects = <String, Uint8List>{};
  int uploads = 0;

  @override
  String get userId => 'user-1';

  @override
  Future<void> upload(String path, Uint8List bytes) async {
    uploads++;
    objects[path] = bytes;
  }

  @override
  Future<Uint8List> download(String path) async => objects[path] ?? (throw const SocketException('нет сети'));

  @override
  Future<bool> exists(String path) async => objects.containsKey(path);
}

void main() {
  late _FakeRecords records;
  late _FakeBlobs blobs;
  late FakeFileStore files;
  late SupabaseSyncRemote remote;

  setUp(() {
    records = _FakeRecords();
    blobs = _FakeBlobs();
    files = FakeFileStore();
    remote = SupabaseSyncRemote(
      records: records,
      externalizer: BlobExternalizer(blobs: blobs, files: files),
    );
  });

  test('push принимает новую запись и пропускает устаревшую, pull отдаёт по курсору порциями', () async {
    final List<PushResult> first = await remote.push(<SyncRecord>[
      rec('project', 'a', at: 10, data: <String, Object?>{'name': 'a'}),
      rec('project', 'b', at: 10, data: <String, Object?>{'name': 'b'}),
    ]);
    expect(first.every((r) => r.accepted), isTrue);

    final List<PushResult> second = await remote.push(<SyncRecord>[
      rec('project', 'a', at: 5, data: <String, Object?>{'name': 'старое'}),
    ]);
    expect(second.single.accepted, isFalse, reason: 'устаревшая запись отвергнута сервером');

    final SyncPage page = await remote.pullSince(0, limit: 1);
    expect(page.records.single.syncId, 'a');
    expect(page.hasMore, isTrue);
    final SyncPage rest = await remote.pullSince(page.cursor, limit: 1);
    expect(rest.records.single.syncId, 'b');
    final SyncPage end = await remote.pullSince(rest.cursor);
    expect(end.records, isEmpty);
    expect(end.cursor, rest.cursor);
    expect(end.hasMore, isFalse);
  });

  test('надгробие уходит с пустой нагрузкой и возвращается надгробием', () async {
    await remote.push(<SyncRecord>[rec('project', 'a', at: 10, deleted: true)]);
    final SyncRecord back = (await remote.pullSince(0)).records.single;
    expect(back.isDeleted, isTrue);
    expect(back.data, isEmpty);
  });

  test('сетка и слои уходят файлами по хешу, в строке остаётся ссылка, при приёме возвращаются байты', () async {
    final String cells = base64Encode(List<int>.generate(2000, (i) => i % 7));
    await remote.push(<SyncRecord>[
      rec('grid_pattern', 'p1', at: 10, data: <String, Object?>{'width': 3, 'cells': cells, 'layers': null}),
    ]);

    final WireRow stored = records.rows['grid_pattern/p1']!;
    final Map<String, Object?> data = stored['data']! as Map<String, Object?>;
    expect((data['cells']! as Map<String, Object?>)['blob'], startsWith('user-1/grid_pattern/p1/cells-'));
    expect(data['width'], 3);
    expect(blobs.objects, hasLength(1));
    expect(blobs.objects.values.single.length, lessThan(2000), reason: 'файл сжат');

    final SyncRecord back = (await remote.pullSince(0)).records.single;
    expect(back.data['cells'], cells);
  });

  test('неизменившийся файл повторно не загружается', () async {
    final String cells = base64Encode(<int>[1, 2, 3]);
    for (final int at in <int>[10, 20]) {
      await remote.push(<SyncRecord>[
        rec('grid_pattern', 'p1', at: at, data: <String, Object?>{'cells': cells}),
      ]);
    }
    expect(blobs.uploads, 1);
  });

  test('страница книги: файл читается из хранилища при отправке и записывается по тому же пути при приёме', () async {
    files.files['pages/a0.png'] = Uint8List.fromList(<int>[9, 8, 7, 6]);
    await remote.push(<SyncRecord>[
      rec('image_pattern_page', 'p:0', at: 10, data: <String, Object?>{'path': 'pages/a0.png', 'width': 10}),
    ]);
    expect(
      ((records.rows['image_pattern_page/p:0']!['data']! as Map<String, Object?>)['file']!
          as Map<String, Object?>)['size'],
      4,
    );

    final FakeFileStore other = FakeFileStore();
    final SupabaseSyncRemote macRemote = SupabaseSyncRemote(
      records: records,
      externalizer: BlobExternalizer(blobs: blobs, files: other),
    );
    final SyncRecord back = (await macRemote.pullSince(0)).records.single;
    expect(other.files['pages/a0.png'], <int>[9, 8, 7, 6]);
    expect(back.data.containsKey('file'), isFalse, reason: 'ссылка на файл в запись не попадает');
  });

  test('файл не скачался: pull падает, запись не применяется, курсор вызывающий не двигает', () async {
    await remote.push(<SyncRecord>[
      rec(
        'grid_pattern',
        'p1',
        at: 10,
        data: <String, Object?>{
          'cells': base64Encode(<int>[1, 2, 3]),
        },
      ),
    ]);
    blobs.objects.clear();
    await expectLater(remote.pullSince(0), throwsA(isA<SocketException>()));
  });

  test('испорченный файл (не сошлась контрольная сумма) отвергается', () async {
    await remote.push(<SyncRecord>[
      rec(
        'grid_pattern',
        'p1',
        at: 10,
        data: <String, Object?>{
          'cells': base64Encode(<int>[1, 2, 3]),
        },
      ),
    ]);
    final String path = blobs.objects.keys.single;
    blobs.objects[path] = Uint8List.fromList(gzip.encode(<int>[9, 9, 9]));
    await expectLater(remote.pullSince(0), throwsA(isA<FileSystemException>()));
  });
}
