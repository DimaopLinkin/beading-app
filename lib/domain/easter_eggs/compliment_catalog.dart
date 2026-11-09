import 'dart:convert';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/easter_eggs/egg_group.dart';
import 'package:equatable/equatable.dart';

/// Один комплимент. [id] стабилен: группа и исходный текст, поэтому Дмитрий дописывает тексты в `ru.json` без правки
/// кода и без номеров. Правка текста = новый комплимент для истории показов.
final class Compliment extends Equatable {
  const Compliment({required this.group, required this.text});

  static const String namePlaceholder = '{name}';

  final EggGroup group;

  /// Текст из файла, возможно с `{name}`.
  final String text;

  String get id => '${group.name}:$text';

  /// Текст для показа: `{name}` заменяется именем пользовательницы.
  String render(String name) => text.replaceAll(namePlaceholder, name);

  @override
  List<Object?> get props => <Object?>[group, text];
}

/// Все комплименты по группам (`assets/compliments/ru.json`).
final class ComplimentCatalog extends Equatable {
  const ComplimentCatalog(this._byGroup);

  /// Формат: `{"completed": ["текст", ...], "rows": [...], ...}` — ровно по ключу на каждую [EggGroup], без пустых.
  static Result<ComplimentCatalog> parse(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException catch (error) {
      return Err<ComplimentCatalog>(ValidationFailure('compliments: не JSON: ${error.message}'));
    }
    if (json is! Map<String, Object?>) {
      return const Err<ComplimentCatalog>(ValidationFailure('compliments: корень должен быть объектом'));
    }
    final Map<String, EggGroup> known = <String, EggGroup>{for (final EggGroup g in EggGroup.values) g.name: g};
    final String? unknown = json.keys.where((key) => !known.containsKey(key)).firstOrNull;
    if (unknown != null) {
      return Err<ComplimentCatalog>(ValidationFailure('compliments: неизвестная группа "$unknown"'));
    }
    final Map<EggGroup, List<Compliment>> byGroup = <EggGroup, List<Compliment>>{};
    for (final EggGroup group in EggGroup.values) {
      final Object? raw = json[group.name];
      if (raw is! List<Object?> || raw.isEmpty) {
        return Err<ComplimentCatalog>(ValidationFailure('compliments: группа "${group.name}" должна быть непустым списком'));
      }
      final List<Compliment> items = <Compliment>[];
      for (final Object? item in raw) {
        if (item is! String || item.trim().isEmpty) {
          return Err<ComplimentCatalog>(ValidationFailure('compliments: в "${group.name}" есть пустой или не строковый текст'));
        }
        items.add(Compliment(group: group, text: item));
      }
      if (items.toSet().length != items.length) {
        return Err<ComplimentCatalog>(ValidationFailure('compliments: в "${group.name}" есть повторяющийся текст'));
      }
      byGroup[group] = List<Compliment>.unmodifiable(items);
    }
    return Success<ComplimentCatalog>(ComplimentCatalog(Map<EggGroup, List<Compliment>>.unmodifiable(byGroup)));
  }

  final Map<EggGroup, List<Compliment>> _byGroup;

  List<Compliment> of(EggGroup group) => _byGroup[group] ?? const <Compliment>[];

  @override
  List<Object?> get props => <Object?>[_byGroup];
}
