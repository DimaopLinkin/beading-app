import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/easter_eggs/compliment_catalog.dart';
import 'package:beading/domain/easter_eggs/compliment_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Тексты из `assets/compliments/ru.json`.
class AssetComplimentSource implements ComplimentSource {
  AssetComplimentSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String assetPath = 'assets/compliments/ru.json';

  final AssetBundle _bundle;

  @override
  Future<Result<ComplimentCatalog>> load() async {
    final String raw;
    try {
      raw = await _bundle.loadString(assetPath);
    } on FlutterError catch (error) {
      return Err<ComplimentCatalog>(StorageFailure('compliments: $error'));
    }
    return ComplimentCatalog.parse(raw);
  }
}
