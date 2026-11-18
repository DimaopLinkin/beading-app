import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_panel.dart';
import 'package:beading/presentation/widgets/min_tap_target.dart';
import 'package:beading/presentation/widgets/pill_chip.dart';
import 'package:flutter/cupertino.dart';

/// Один чип пропорций в ленте панели.
class CropChipData {
  const CropChipData({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;
}

/// Стеклянная панель редактора обрезки (слой управления): кнопка переворота, чипы пропорций, подсказка и «Сбросить».
///
/// Внутри панели стекла нет (не ставим стекло на стекло): кнопка и чипы залиты системной заливкой. На широком окне
/// («Сбросить» живёт в нижней строке кнопок) [onReset] не задаётся.
class CropPresetsPanel extends StatelessWidget {
  const CropPresetsPanel({
    required this.freeSelected,
    required this.onFree,
    required this.chips,
    required this.onRotate,
    this.rotateReason,
    this.hint,
    this.onReset,
    super.key,
  });

  final bool freeSelected;
  final VoidCallback onFree;
  final List<CropChipData> chips;

  /// `null` — переворот недоступен (квадрат, размер вышивки или рамка свободна).
  final VoidCallback? onRotate;

  /// Почему переворот недоступен; показывается с иконкой под кнопкой, не только цветом.
  final String? rotateReason;

  /// Подсказка при выбранном чипе.
  final String? hint;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle caption = CupertinoTheme.of(context).textTheme.textStyle.copyWith(
      fontSize: 13,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    return GlassPanel(
      padding: EdgeInsets.all(tokens.spacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (hint != null || onReset != null)
            Row(
              children: <Widget>[
                Expanded(child: Text(hint ?? '', style: caption)),
                if (onReset != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.square(tokens.minTapTarget),
                    onPressed: onReset,
                    child: Text(l10n.importCropReset),
                  ),
              ],
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                children: <Widget>[
                  _RotateButton(onPressed: onRotate, label: l10n.cropRotateFrame),
                ],
              ),
              SizedBox(width: tokens.spacing.s),
              Expanded(
                child: ShaderMask(
                  // Затухание справа подсказывает, что ленту можно прокрутить.
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: <Color>[Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                    stops: <double>[0, 0.9, 1],
                  ).createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        PillChip(label: l10n.cropFree, selected: freeSelected, onTap: onFree),
                        for (final CropChipData chip in chips)
                          PillChip(label: chip.label, selected: chip.selected, onTap: chip.onTap),
                        SizedBox(width: tokens.spacing.l),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (rotateReason != null)
            Padding(
              padding: EdgeInsets.only(top: tokens.spacing.xs),
              child: Row(
                children: <Widget>[
                  Icon(AppIcons.info, size: 15, color: caption.color),
                  SizedBox(width: tokens.spacing.xs),
                  Expanded(child: Text(rotateReason!, style: caption)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Круглая кнопка «Повернуть рамку». Неактивная приглушена.
class _RotateButton extends StatelessWidget {
  const _RotateButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final bool enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: MinTapTarget(
          child: Opacity(
            opacity: enabled ? 1 : tokens.disabledOpacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              ),
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing.s),
                child: Icon(AppIcons.rotateFrame, size: 22, color: CupertinoTheme.of(context).primaryColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
