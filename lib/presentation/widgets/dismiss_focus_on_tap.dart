import 'package:flutter/cupertino.dart';

/// Тап по пустому месту снимает фокус с текстового поля и прячет клавиатуру, как в нативных iOS-экранах.
/// Тап по самому полю сюда не доходит: его обрабатывает поле.
class DismissFocusOnTap extends StatelessWidget {
  const DismissFocusOnTap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    child: child,
  );
}
