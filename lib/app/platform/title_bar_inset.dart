import 'package:beading/app/platform/desktop_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// На macOS окно с скрытым заголовком: кнопки окна лежат поверх контента.
/// Добавляет сверху [macTitleBarInset] в `MediaQuery.padding`, чтобы панели навигации
/// и экраны начинались ниже кнопок. На других платформах ничего не меняет.
class TitleBarInset extends StatelessWidget {
  const TitleBarInset({required this.child, this.platform, super.key});

  final Widget child;

  /// Подмена платформы в тестах; по умолчанию [defaultTargetPlatform].
  final TargetPlatform? platform;

  @override
  Widget build(BuildContext context) {
    if ((platform ?? defaultTargetPlatform) != TargetPlatform.macOS) {
      return child;
    }
    final MediaQueryData data = MediaQuery.of(context);
    if (data.padding.top >= macTitleBarInset) {
      return child;
    }
    final EdgeInsets padding = data.padding.copyWith(top: macTitleBarInset);
    return MediaQuery(
      data: data.copyWith(
        padding: padding,
        viewPadding: data.viewPadding.copyWith(top: macTitleBarInset),
      ),
      child: child,
    );
  }
}
