import 'package:equatable/equatable.dart';

/// Одна страница схемы: файл с картинкой внутри хранилища приложения.
class ImagePatternPage extends Equatable {
  const ImagePatternPage({required this.id, required this.path, required this.width, required this.height});

  final String id;

  /// Путь к PNG относительно хранилища приложения.
  final String path;

  /// Размер картинки в пикселях.
  final int width;
  final int height;

  @override
  List<Object?> get props => <Object?>[id, path, width, height];
}

/// Схема из книги: упорядоченный список страниц проекта с `contentKind = image`.
class ImagePattern extends Equatable {
  const ImagePattern({required this.id, required this.projectId, required this.pages});

  final String id;
  final String projectId;

  /// В порядке чтения; у вышивки их может быть много.
  final List<ImagePatternPage> pages;

  @override
  List<Object?> get props => <Object?>[id, projectId, pages];
}
