import 'package:beading/domain/catalog/code_search_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('codeSearchKey', () {
    test('DB-0010, db10, DB 10 и db0010 дают один ключ', () {
      final Set<String> keys = <String>{
        for (final String v in <String>['DB-0010', 'db10', 'DB 10', 'db0010']) codeSearchKey(v),
      };
      expect(keys, <String>{'db10'});
    });

    test('ноль сам по себе не пропадает', () {
      expect(codeSearchKey('0'), '0');
      expect(codeSearchKey('DB0000'), 'db0');
    });

    test('буквенный суффикс сохраняется', () {
      expect(codeSearchKey('0049F'), '49f');
    });

    test('разделители убираются до обработки нулей', () {
      expect(codeSearchKey('DB11-0010'), 'db110010');
    });
  });

  group('numericPart', () {
    test('отбрасывает буквенную приставку', () {
      expect(numericPart('db10'), '10');
      expect(numericPart('10'), '10');
      expect(numericPart('49f'), '49f');
    });
  });
}
