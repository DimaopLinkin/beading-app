import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/sharing/text_sharer.dart';

/// Запоминает, чем поделились. [fail] — следующий вызов вернёт ошибку платформы.
class FakeTextSharer implements TextSharer {
  final List<({String text, String? subject, ShareOrigin? origin})> shared =
      <({String text, String? subject, ShareOrigin? origin})>[];
  bool fail = false;

  @override
  Future<Result<void>> shareText(String text, {String? subject, ShareOrigin? origin}) async {
    shared.add((text: text, subject: subject, origin: origin));
    return fail ? const Err<void>(UnexpectedFailure('boom')) : const Success<void>(null);
  }
}
