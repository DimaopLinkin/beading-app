import 'dart:ui' show Rect;

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:share_plus/share_plus.dart';

/// Системный лист «Поделиться» (iOS, macOS) через `share_plus`.
class SharePlusTextSharer implements TextSharer {
  /// [share] подменяют в тестах; по умолчанию — `SharePlus.instance.share`.
  SharePlusTextSharer({Future<ShareResult> Function(ShareParams params)? share})
    : _share = share ?? SharePlus.instance.share;

  final Future<ShareResult> Function(ShareParams params) _share;

  @override
  Future<Result<void>> shareText(String text, {String? subject, ShareOrigin? origin}) async {
    try {
      final ShareResult result = await _share(
        ShareParams(
          text: text,
          subject: subject,
          sharePositionOrigin: origin == null
              ? null
              : Rect.fromLTWH(origin.left, origin.top, origin.width, origin.height),
          // Только системный лист: без письма и без скачивания файла.
          downloadFallbackEnabled: false,
          mailToFallbackEnabled: false,
        ),
      );
      // Закрытый без выбора лист — не ошибка.
      return result.status == ShareResultStatus.unavailable
          ? const Err<void>(UnexpectedFailure('Системный лист «Поделиться» недоступен'))
          : const Success<void>(null);
    } on Object catch (e) {
      return Err<void>(UnexpectedFailure('Не удалось поделиться: $e'));
    }
  }
}
