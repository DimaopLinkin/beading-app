import 'package:beading/domain/projects/craft.dart';
import 'package:equatable/equatable.dart';

enum ProjectStatus { idea, inProgress, done }

/// Что лежит внутри проекта: фото страницы книги, сетка схемы или пошаговая инструкция.
enum ContentKind { image, grid, steps }

/// Проект — корень библиотеки.
class Project extends Equatable {
  const Project({
    required this.id,
    required this.name,
    required this.status,
    required this.craft,
    required this.technique,
    required this.contentKind,
    required this.notes,
    required this.coverPath,
    required this.lastWorkedAt,
  });

  final String id;
  final String name;
  final ProjectStatus status;
  final Craft craft;
  final Technique technique;
  final ContentKind contentKind;
  final String notes;

  /// Путь к обложке относительно хранилища приложения; `null`, пока обложки нет.
  final String? coverPath;

  /// Когда над проектом работали в последний раз (UTC). Определяет порядок в библиотеке.
  final DateTime lastWorkedAt;

  Project copyWith({
    String? name,
    ProjectStatus? status,
    String? notes,
    DateTime? lastWorkedAt,
  }) => Project(
    id: id,
    name: name ?? this.name,
    status: status ?? this.status,
    craft: craft,
    technique: technique,
    contentKind: contentKind,
    notes: notes ?? this.notes,
    coverPath: coverPath,
    lastWorkedAt: lastWorkedAt ?? this.lastWorkedAt,
  );

  /// Копия с другой обложкой; `null` убирает обложку.
  Project withCoverPath(String? path) => Project(
    id: id,
    name: name,
    status: status,
    craft: craft,
    technique: technique,
    contentKind: contentKind,
    notes: notes,
    coverPath: path,
    lastWorkedAt: lastWorkedAt,
  );

  @override
  List<Object?> get props => <Object?>[
    id,
    name,
    status,
    craft,
    technique,
    contentKind,
    notes,
    coverPath,
    lastWorkedAt,
  ];
}
