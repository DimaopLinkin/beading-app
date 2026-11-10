import 'package:beading/core/result.dart';
import 'package:equatable/equatable.dart';

/// Прямоугольник кнопки «Поделиться» в координатах окна: от него открывается лист «Поделиться» на iPad и macOS.
final class ShareOrigin extends Equatable {
  const ShareOrigin({required this.left, required this.top, required this.width, required this.height});

  final double left;
  final double top;
  final double width;
  final double height;

  @override
  List<Object?> get props => <Object?>[left, top, width, height];
}

/// Отдаёт текст системному листу «Поделиться» (сообщения, заметки, почта, AirDrop).
abstract interface class TextSharer {
  /// Ошибка платформы приходит как `UnexpectedFailure`; закрытый пользователем лист — успех.
  Future<Result<void>> shareText(String text, {String? subject, ShareOrigin? origin});
}
