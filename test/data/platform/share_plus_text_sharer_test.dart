import 'dart:ui' show Rect;

import 'package:beading/core/failure.dart';
import 'package:beading/data/platform/share_plus_text_sharer.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

class _FakePlatform {
  ShareParams? params;
  ShareResult result = const ShareResult('', ShareResultStatus.success);
  Exception? error;

  Future<ShareResult> share(ShareParams params) async {
    this.params = params;
    if (error != null) throw error!;
    return result;
  }
}

void main() {
  late _FakePlatform platform;
  late SharePlusTextSharer sharer;

  setUp(() {
    platform = _FakePlatform();
    sharer = SharePlusTextSharer(share: platform.share);
  });

  test('отдаёт текст, тему и прямоугольник кнопки системному листу, без запасных путей', () async {
    final result = await sharer.shareText(
      'список',
      subject: 'Материалы',
      origin: const ShareOrigin(left: 10, top: 20, width: 30, height: 40),
    );

    expect(result.isSuccess, isTrue);
    expect(platform.params!.text, 'список');
    expect(platform.params!.subject, 'Материалы');
    expect(platform.params!.sharePositionOrigin, const Rect.fromLTWH(10, 20, 30, 40));
    expect(platform.params!.downloadFallbackEnabled, isFalse);
    expect(platform.params!.mailToFallbackEnabled, isFalse);
  });

  test('без прямоугольника кнопки (iPhone) передаётся null', () async {
    await sharer.shareText('список');

    expect(platform.params!.sharePositionOrigin, isNull);
  });

  test('лист закрыт без выбора — не ошибка', () async {
    platform.result = const ShareResult('', ShareResultStatus.dismissed);

    expect((await sharer.shareText('список')).isSuccess, isTrue);
  });

  test('системный лист недоступен — UnexpectedFailure', () async {
    platform.result = const ShareResult('', ShareResultStatus.unavailable);

    expect((await sharer.shareText('список')).failureOrNull, isA<UnexpectedFailure>());
  });

  test('исключение платформы превращается в UnexpectedFailure', () async {
    platform.error = Exception('нет окна');

    expect((await sharer.shareText('список')).failureOrNull, isA<UnexpectedFailure>());
  });
}
