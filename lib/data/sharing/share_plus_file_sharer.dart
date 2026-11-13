import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/sharing/file_sharer.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:share_plus/share_plus.dart';

/// Системный лист «Поделиться» для файла (iOS, macOS) через `share_plus`.
class SharePlusFileSharer implements FileSharer {
  /// [share] подменяют в тестах.
  SharePlusFileSharer({Future<ShareResult> Function(ShareParams params)? share})
    : _share = share ?? SharePlus.instance.share;

  final Future<ShareResult> Function(ShareParams params) _share;

  @override
  Future<Result<void>> shareFile({required Uint8List bytes, required String fileName, ShareOrigin? origin}) async {
    try {
      final ShareResult result = await _share(
        ShareParams(
          files: <XFile>[XFile.fromData(bytes, name: fileName, mimeType: 'application/octet-stream')],
          fileNameOverrides: <String>[fileName],
          sharePositionOrigin: origin == null
              ? null
              : Rect.fromLTWH(origin.left, origin.top, origin.width, origin.height),
          downloadFallbackEnabled: false,
          mailToFallbackEnabled: false,
        ),
      );
      return result.status == ShareResultStatus.unavailable
          ? const Err<void>(UnexpectedFailure('Системный лист «Поделиться» недоступен'))
          : const Success<void>(null);
    } on Object catch (e) {
      return Err<void>(UnexpectedFailure('Не удалось поделиться: $e'));
    }
  }
}
