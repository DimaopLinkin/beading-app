import 'dart:async';

import 'package:beading/domain/easter_eggs/shown_compliment.dart';
import 'package:beading/presentation/easter_eggs/compliment_banner_cubit.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Кладёт баннер-комплимент поверх приложения. Баннер у верхнего края, поэтому нижние кнопки плетения никогда не
/// перекрыты; вне самого баннера нажатия проходят к экрану.
class ComplimentOverlay extends StatelessWidget {
  const ComplimentOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => BlocListener<ComplimentBannerCubit, ShownCompliment?>(
    listenWhen: (previous, current) => current != null,
    listener: (context, _) => unawaited(HapticFeedback.lightImpact()),
    child: Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: BlocBuilder<ComplimentBannerCubit, ShownCompliment?>(
              builder: (context, compliment) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (widget, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(animation),
                    child: widget,
                  ),
                ),
                child: compliment == null
                    ? const SizedBox.shrink()
                    : Dismissible(
                        key: ValueKey<String>(compliment.text),
                        direction: DismissDirection.up,
                        onDismissed: (_) => context.read<ComplimentBannerCubit>().dismiss(),
                        child: ComplimentBanner(text: compliment.text),
                      ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Сам баннер: стеклянная панель с иконкой-бусинкой и текстом в одну-две строки.
class ComplimentBanner extends StatelessWidget {
  const ComplimentBanner({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l, vertical: tokens.spacing.s),
        child: GlassPanel(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l, vertical: tokens.spacing.m),
          child: Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoDynamicColor.resolve(tokens.accent, context),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: tokens.spacing.l),
              ),
              SizedBox(width: tokens.spacing.m),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CupertinoTheme.of(context).textTheme.textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
