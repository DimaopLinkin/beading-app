import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';

/// Одно действие, которое открывает свайп по строке.
@immutable
class SwipeAction {
  const SwipeAction({required this.label, required this.color, required this.onPressed});

  final String label;
  final Color color;
  final VoidCallback onPressed;
}

/// Строка, которую можно сдвинуть влево, открыв кнопки действий (как в системных списках iOS).
///
/// Те же действия доступны VoiceOver через пользовательские действия семантики.
class SwipeActionRow extends StatefulWidget {
  const SwipeActionRow({required this.child, required this.actions, this.actionWidth = 84, super.key});

  final Widget child;
  final List<SwipeAction> actions;
  final double actionWidth;

  @override
  State<SwipeActionRow> createState() => _SwipeActionRowState();
}

class _SwipeActionRowState extends State<SwipeActionRow> {
  double _offset = 0;
  bool _dragging = false;

  double get _extent => widget.actionWidth * widget.actions.length;

  bool get _isOpen => _offset < 0;

  void _close() => setState(() => _offset = 0);

  void _onDragUpdate(DragUpdateDetails details) =>
      setState(() => _offset = (_offset + details.delta.dx).clamp(-_extent, 0));

  void _onDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    final bool open = velocity < -300 || (velocity <= 300 && _offset < -_extent / 2);
    setState(() {
      _dragging = false;
      _offset = open ? -_extent : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        for (final SwipeAction action in widget.actions) CustomSemanticsAction(label: action.label): action.onPressed,
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radius.m),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: ExcludeSemantics(
                  excluding: !_isOpen,
                  child: SizedBox(
                    width: _extent,
                    child: Row(
                      children: <Widget>[
                        for (final SwipeAction action in widget.actions)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                _close();
                                action.onPressed();
                              },
                              child: ColoredBox(
                                color: action.color,
                                child: Center(
                                  child: Text(
                                    action.label,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onHorizontalDragStart: (_) => setState(() => _dragging = true),
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onHorizontalDragCancel: () => setState(() {
                _dragging = false;
                _offset = _offset < -_extent / 2 ? -_extent : 0;
              }),
              child: AnimatedContainer(
                duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(_offset, 0, 0),
                // Одна и та же пара обёрток при открытой и закрытой строке: иначе карточка пересоздавалась бы.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _isOpen ? _close : null,
                  child: AbsorbPointer(absorbing: _isOpen, child: widget.child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
