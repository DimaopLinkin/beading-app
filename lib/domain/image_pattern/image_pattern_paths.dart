/// Где лежат файлы страниц схемы внутри хранилища приложения.
String imagePatternPagePath({required String patternId, required String pageId}) =>
    'book_patterns/$patternId/$pageId.png';
