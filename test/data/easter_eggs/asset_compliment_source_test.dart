import 'package:beading/core/failure.dart';
import 'package:beading/data/easter_eggs/asset_compliment_source.dart';
import 'package:beading/domain/easter_eggs/egg_group.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.content);

  final String? content;

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (content == null) {
      throw FlutterError('нет файла $key');
    }
    return content!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('настоящий ассет загружается и разбирается', () async {
    final result = await AssetComplimentSource(bundle: rootBundle).load();

    expect(result.valueOrNull!.of(EggGroup.completed), isNotEmpty);
  });

  test('битый JSON — ValidationFailure', () async {
    final result = await AssetComplimentSource(bundle: _Bundle('{')).load();

    expect(result.failureOrNull, isA<ValidationFailure>());
  });

  test('нет файла — Failure, а не исключение', () async {
    final result = await AssetComplimentSource(bundle: _Bundle(null)).load();

    expect(result.failureOrNull, isA<StorageFailure>());
  });
}
