import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

/// Способ завести проект в листе «Новый проект». Пункты добавляют фичи (книга, редактор, генерация) через
/// [NewProjectRegistry]; сама библиотека их не знает.
@immutable
class NewProjectEntry {
  const NewProjectEntry({
    required this.id,
    required this.craft,
    required this.title,
    required this.icon,
    required this.onSelected,
    this.order = 100,
  });

  /// Уникален среди пунктов; повторная регистрация с тем же [id] заменяет пункт.
  final String id;

  /// Для какого ремесла пункт показывается: лист сначала спрашивает ремесло.
  final Craft craft;
  final String Function(AppLocalizations l10n) title;
  final IconData icon;

  /// Вызывается после закрытия листа; [context] — контекст экрана библиотеки.
  final Future<void> Function(BuildContext context) onSelected;

  /// Меньше — выше в списке.
  final int order;
}

class NewProjectRegistry {
  final Map<String, NewProjectEntry> _entries = <String, NewProjectEntry>{};

  void register(NewProjectEntry entry) => _entries[entry.id] = entry;

  /// Ремёсла, у которых есть хотя бы один пункт, в порядке перечисления [Craft].
  List<Craft> get crafts =>
      Craft.values.where((craft) => _entries.values.any((e) => e.craft == craft)).toList(growable: false);

  List<NewProjectEntry> entriesFor(Craft craft) =>
      _entries.values.where((e) => e.craft == craft).toList()..sort((a, b) => a.order.compareTo(b.order));
}
