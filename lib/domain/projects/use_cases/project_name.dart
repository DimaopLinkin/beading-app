import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';

const int maxProjectNameLength = 120;

/// Проверяет название и возвращает его без пробелов по краям.
Result<String> validateProjectName(String raw) {
  final String name = raw.trim();
  if (name.isEmpty) {
    return const Err<String>(ValidationFailure('Название проекта пустое'));
  }
  if (name.length > maxProjectNameLength) {
    return const Err<String>(ValidationFailure('Название длиннее $maxProjectNameLength символов'));
  }
  return Success<String>(name);
}
