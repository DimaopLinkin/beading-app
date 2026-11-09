import 'dart:convert';
import 'dart:io';

import 'package:beading/core/failure.dart';
import 'package:beading/domain/easter_eggs/compliment_catalog.dart';
import 'package:beading/domain/easter_eggs/egg_group.dart';
import 'package:flutter_test/flutter_test.dart';

String _json(Map<String, Object?> groups) => jsonEncode(groups);

Map<String, Object?> _full() => <String, Object?>{
  for (final EggGroup group in EggGroup.values) group.name: <String>['Текст ${group.name} 1', 'Текст ${group.name} 2'],
};

void main() {
  group('ComplimentCatalog.parse', () {
    test('разбирает все группы, id собирается из группы и текста', () {
      final ComplimentCatalog catalog = ComplimentCatalog.parse(_json(_full())).valueOrNull!;

      expect(catalog.of(EggGroup.completed), hasLength(2));
      expect(catalog.of(EggGroup.completed).first.text, 'Текст completed 1');
      expect(catalog.of(EggGroup.completed).first.id, 'completed:Текст completed 1');
      expect(catalog.of(EggGroup.completed).first.group, EggGroup.completed);
    });

    test('не JSON — ошибка', () {
      expect(ComplimentCatalog.parse('{').failureOrNull, isA<ValidationFailure>());
    });

    test('корень не объект — ошибка', () {
      expect(ComplimentCatalog.parse('[]').failureOrNull, isA<ValidationFailure>());
    });

    test('неизвестная группа — ошибка (опечатка в ключе)', () {
      final Map<String, Object?> data = _full()..['complted'] = <String>['x'];

      expect(ComplimentCatalog.parse(_json(data)).failureOrNull, isA<ValidationFailure>());
    });

    test('не хватает группы — ошибка', () {
      final Map<String, Object?> data = _full()..remove('secret');

      expect(ComplimentCatalog.parse(_json(data)).failureOrNull, isA<ValidationFailure>());
    });

    test('пустая группа — ошибка', () {
      final Map<String, Object?> data = _full()..['rows'] = <String>[];

      expect(ComplimentCatalog.parse(_json(data)).failureOrNull, isA<ValidationFailure>());
    });

    test('не строка или пустой/пробельный текст — ошибка', () {
      expect(ComplimentCatalog.parse(_json(_full()..['rows'] = <Object>[1])).failureOrNull, isA<ValidationFailure>());
      expect(
        ComplimentCatalog.parse(_json(_full()..['rows'] = <String>['  '])).failureOrNull,
        isA<ValidationFailure>(),
      );
    });

    test('повтор текста внутри группы — ошибка', () {
      final Map<String, Object?> data = _full()..['rows'] = <String>['a', 'a'];

      expect(ComplimentCatalog.parse(_json(data)).failureOrNull, isA<ValidationFailure>());
    });
  });

  group('Compliment.render', () {
    test('подставляет имя вместо {name}', () {
      final Compliment compliment = ComplimentCatalog.parse(
        _json(_full()..['completed'] = <String>['{name}, это шедевр']),
      ).valueOrNull!.of(EggGroup.completed).single;

      expect(compliment.render('Настя'), 'Настя, это шедевр');
      expect(compliment.render('Маша'), 'Маша, это шедевр');
    });

    test('текст без плейсхолдера не меняется', () {
      final Compliment compliment = ComplimentCatalog.parse(_json(_full())).valueOrNull!.of(EggGroup.rows).first;

      expect(compliment.render('Настя'), compliment.text);
    });
  });

  group('assets/compliments/ru.json', () {
    late ComplimentCatalog catalog;

    setUp(() {
      catalog = ComplimentCatalog.parse(File('assets/compliments/ru.json').readAsStringSync()).valueOrNull!;
    });

    test('всего 40–60 текстов, каждая группа непуста', () {
      final int total = EggGroup.values.fold(0, (sum, group) => sum + catalog.of(group).length);

      expect(total, inInclusiveRange(40, 60));
      for (final EggGroup group in EggGroup.values) {
        expect(catalog.of(group), isNotEmpty, reason: group.name);
      }
    });

    test('тексты не пустые, не длиннее 70 символов и уникальны во всём файле', () {
      final List<String> texts = <String>[
        for (final EggGroup group in EggGroup.values) ...catalog.of(group).map((c) => c.text),
      ];

      for (final String text in texts) {
        expect(text.trim(), isNotEmpty);
        // Длина считается по готовой строке с самым длинным именем по умолчанию.
        expect(text.replaceAll('{name}', 'Настя').length, lessThanOrEqualTo(70), reason: text);
      }
      expect(texts.toSet(), hasLength(texts.length), reason: 'тексты уникальны');
    });

    test('«готово» и «ряды» содержат достаточно разных текстов для ротации', () {
      expect(catalog.of(EggGroup.completed).length, greaterThanOrEqualTo(6));
      expect(catalog.of(EggGroup.rows).length, greaterThanOrEqualTo(6));
    });

    test('часть текстов обращается по имени', () {
      final int withName = <Compliment>[
        for (final EggGroup group in EggGroup.values) ...catalog.of(group),
      ].where((c) => c.text.contains('{name}')).length;

      expect(withName, greaterThan(5));
    });
  });
}
