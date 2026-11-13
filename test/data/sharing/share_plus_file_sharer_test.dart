import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:beading/core/failure.dart';
import 'package:beading/data/sharing/share_plus_file_sharer.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  ShareParams? params;
  ShareResult result = const ShareResult('', ShareResultStatus.success);
  Exception? error;

  Future<ShareResult> share(ShareParams p) async {
    params = p;
    if (error != null) throw error!;
    return result;
  }

  setUp(() {
    params = null;
    result = const ShareResult('', ShareResultStatus.success);
    error = null;
  });

  test('отдаёт файл с именем и прямоугольником кнопки, без запасных путей', () async {
    final sharer = SharePlusFileSharer(share: share);
    final r = await sharer.shareFile(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileName: 'Роза.biser',
      origin: const ShareOrigin(left: 1, top: 2, width: 3, height: 4),
    );
    expect(r.isSuccess, isTrue);
    expect(params!.files, hasLength(1));
    expect(params!.fileNameOverrides, <String>['Роза.biser']);
    expect(params!.sharePositionOrigin, const Rect.fromLTWH(1, 2, 3, 4));
    expect(params!.downloadFallbackEnabled, isFalse);
    expect(params!.mailToFallbackEnabled, isFalse);
  });

  test('лист недоступен — ошибка; закрытый лист — успех; исключение — ошибка', () async {
    final sharer = SharePlusFileSharer(share: share);
    result = const ShareResult('', ShareResultStatus.unavailable);
    expect((await sharer.shareFile(bytes: Uint8List(1), fileName: 'a.biser')).failureOrNull, isA<UnexpectedFailure>());
    result = const ShareResult('', ShareResultStatus.dismissed);
    expect((await sharer.shareFile(bytes: Uint8List(1), fileName: 'a.biser')).isSuccess, isTrue);
    error = Exception('boom');
    expect((await sharer.shareFile(bytes: Uint8List(1), fileName: 'a.biser')).failureOrNull, isA<UnexpectedFailure>());
  });
}
