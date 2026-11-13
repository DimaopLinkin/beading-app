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

    test('пробелы и дефис после букв убираются до обработки нулей', () {
      expect(codeSearchKey('DB-0010'), 'db10');
      expect(codeSearchKey('DB 0010'), 'db10');
    });

    test('дефис между цифрами сохраняется: DB0106-1 и DB1061 — разные бусины', () {
      expect(codeSearchKey('DB0106-1'), 'db106-1');
      expect(codeSearchKey('DB1061'), 'db1061');
      expect(codeSearchKey('db 106-1'), codeSearchKey('DB0106-1'));
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
