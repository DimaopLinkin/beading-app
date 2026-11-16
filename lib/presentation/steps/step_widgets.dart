import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:flutter/cupertino.dart';

/// Буква цвета в палитре работы: A, B, … Z, AA, AB, … Буквы нужны, чтобы различать похожие цвета не только цветом.
String paletteLetter(int index) {
  const int alphabet = 26;
  String out = '';
  int n = index;
  do {
    out = String.fromCharCode(0x41 + n % alphabet) + out;
    n = n ~/ alphabet - 1;
  } while (n >= 0);
  return out;
}

/// Чип бусин «3 × A»: кружок цвета палитры (темой не меняется), число и буква. Общий для экрана работы и редактора.
class BeadChip extends StatelessWidget {
  const BeadChip({required this.bead, required this.palette, super.key});

  final StepBead bead;
  final List<PatternColor> palette;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final bool known = bead.colorIndex >= 0 && bead.colorIndex < palette.length;
    final String letter = paletteLetter(bead.colorIndex);
    return Semantics(
      label: AppLocalizations.of(context).stepsBeadChip(bead.count, letter, known ? palette[bead.colorIndex].name : ''),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(tokens.radius.l),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s, vertical: tokens.spacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (known) ColorSwatchView(rgb: palette[bead.colorIndex].rgb, size: 24),
              SizedBox(width: tokens.spacing.xs),
              Text('${bead.count} × $letter', style: tokens.typography.headline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Сегменты повтора: пройденные, текущий и оставшиеся. Индикатор, не кнопка; число считается текстом рядом.
class RepeatSegments extends StatelessWidget {
  const RepeatSegments({required this.pass, required this.total, super.key});

  /// Номер текущего прохода с единицы.
  final int pass;
  final int total;

  /// Больше сегментов не рисуем: длинные повторы показывает только текст.
  static const int maxSegments = 12;

  @override
  Widget build(BuildContext context) {
    if (total > maxSegments) {
      return const SizedBox.shrink();
    }
    final AppTokensData tokens = context.tokens;
    return ExcludeSemantics(
      child: Row(
        children: <Widget>[
          for (int i = 1; i <= total; i++)
            Expanded(
              child: Container(
                height: 6,
                margin: EdgeInsets.only(right: i == total ? 0 : 4),
                decoration: BoxDecoration(
                  color: i <= pass
                      ? tokens.accent.resolveFrom(context)
                      : CupertinoColors.systemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Одна картинка шага из хранилища; при сбое — заглушка с «Повторить».
class StepImageView extends StatefulWidget {
  const StepImageView({required this.files, required this.image, this.fit = BoxFit.contain, super.key});

  final FileStore files;
  final StepImage image;
  final BoxFit fit;

  @override
  State<StepImageView> createState() => _StepImageViewState();
}

class _StepImageViewState extends State<StepImageView> {
  late Future<Result<Uint8List>> _bytes = widget.files.read(widget.image.path);

  @override
  void didUpdateWidget(StepImageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.path != widget.image.path || oldWidget.files != widget.files) {
      _bytes = widget.files.read(widget.image.path);
    }
  }

  void _retry() => setState(() => _bytes = widget.files.read(widget.image.path));

  @override
  Widget build(BuildContext context) => FutureBuilder<Result<Uint8List>>(
    future: _bytes,
    builder: (context, snapshot) {
      final Uint8List? data = snapshot.data?.valueOrNull;
      if (data != null) {
        return Image.memory(
          data,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (context, _, _) => _ImageProblem(onRetry: _retry),
        );
      }
      if (snapshot.hasData) {
        return _ImageProblem(onRetry: _retry);
      }
      return const Center(child: CupertinoActivityIndicator());
    },
  );
}

class _ImageProblem extends StatelessWidget {
  const _ImageProblem({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(l10n.stepsImageFailed, textAlign: TextAlign.center),
          CupertinoButton(onPressed: onRetry, child: Text(l10n.stepsRetry)),
        ],
      ),
    );
  }
}

/// Фото шага: листаются свайпом, щипок увеличивает, внизу счётчик «2 из 3». Шаг без фото ничего не рисует.
class StepImagesPager extends StatefulWidget {
  const StepImagesPager({required this.files, required this.images, this.height = 260, super.key});

  final FileStore files;
  final List<StepImage> images;
  final double height;

  @override
  State<StepImagesPager> createState() => _StepImagesPagerState();
}

class _StepImagesPagerState extends State<StepImagesPager> {
  int _page = 0;

  @override
  void didUpdateWidget(StepImagesPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= widget.images.length) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }
    final AppTokensData tokens = context.tokens;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radius.m),
          child: ColoredBox(
            color: tokens.colors.surface.resolveFrom(context),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: PageView.builder(
                itemCount: widget.images.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: StepImageView(files: widget.files, image: widget.images[i]),
                ),
              ),
            ),
          ),
        ),
        if (widget.images.length > 1)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.xs),
            child: Text(
              l10n.stepsImageCounter(_page + 1, widget.images.length),
              style: tokens.typography.caption.copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
            ),
          ),
      ],
    );
  }
}
