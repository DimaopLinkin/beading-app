import 'package:beading/domain/sync/merge_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sync_fakes.dart';

void main() {
  group('resolve', () {
    test('новее выигрывает, в том числе надгробие над правкой', () {
      final local = rec('project', 'p', at: 10, data: <String, Object?>{'name': 'a'});
      final remote = rec('project', 'p', at: 20, deleted: true);
      expect(MergePolicy.resolve(local, remote), remote);
      expect(MergePolicy.resolve(remote, local), remote);
    });

    test('при равном времени выигрывает больший deviceId, результат не зависит от порядка', () {
      final a = rec('project', 'p', at: 10, data: <String, Object?>{'name': 'a'});
      final b = rec('project', 'p', at: 10, device: 'B', data: <String, Object?>{'name': 'b'});
      expect(MergePolicy.resolve(a, b), b);
      expect(MergePolicy.resolve(b, a), b);
    });

    test('нет локальной записи: берём удалённую; одинаковые: остаётся локальная', () {
      final r = rec('project', 'p', at: 1);
      expect(MergePolicy.resolve(null, r), r);
      expect(MergePolicy.resolve(r, r), same(r));
    });
  });

  group('nextUpdatedAt', () {
    test('обычные часы: берём now', () {
      expect(MergePolicy.nextUpdatedAt(now: 100, previous: 50), 100);
      expect(MergePolicy.nextUpdatedAt(now: 100), 100);
    });

    test('часы ушли назад или совпали: правка всё равно новее версии, поверх которой сделана', () {
      expect(MergePolicy.nextUpdatedAt(now: 100, previous: 500), 501);
      expect(MergePolicy.nextUpdatedAt(now: 100, previous: 100), 101);
    });
  });
}
