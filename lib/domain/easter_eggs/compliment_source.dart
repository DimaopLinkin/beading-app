import 'package:beading/core/result.dart';
import 'package:beading/domain/easter_eggs/compliment_catalog.dart';

/// Откуда берутся тексты комплиментов (файл в ассетах).
abstract interface class ComplimentSource {
  Future<Result<ComplimentCatalog>> load();
}
