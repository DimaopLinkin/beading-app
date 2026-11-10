import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/book_work/pattern_zone.dart';
import 'package:beading/domain/image_pattern/book_work/ruler_state.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/image_pattern/image_pattern.dart';
import 'package:beading/presentation/book_work/ruler_colors.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/row_ring.dart';
import 'package:flutter/cupertino.dart';

/// Страница схемы вместе с линейкой. Рисуется в системе координат страницы: линейка и притушение масштабируются
/// вместе с картинкой, поэтому вид зума её не искажает.
class PageCanvas extends StatelessWidget {
  const PageCanvas({
    required this.files,
    required this.page,
    required this.ruler,
    required this.width,
    this.showZoneFrame = false,
    super.key,
  });

  final FileStore files;
  final ImagePatternPage page;
  final RulerState ruler;

  /// Рамка зоны схемы: показывается, пока границы выбирают.
  final bool showZoneFrame;

  /// Ширина, в которую вписана страница (при зуме 1×).
  final double width;

  /// Высота страницы при ширине [width].
  double get height => width * page.height / page.width;

  @override
  Widget build(BuildContext context) {
    final double scale = width / page.width;
    final Color fill = RulerColors.fill(context, ruler.highlight);
    final Color dim = context.tokens.rowDim.resolveFrom(context);
    final PatternZone zone = ruler.zone ?? PatternZone.full(page.width.toDouble(), page.height.toDouble());
    final double left = zone.left * scale;
    final double right = zone.right * scale;
    final double zoneTop = zone.top * scale;
    final double zoneBottom = zone.bottom * scale;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        // Кольцо рисуется снаружи полосы: на верхнем и нижнем ряду страницы оно выходит за её край.
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: _PageImage(files: files, path: page.path),
          ),
          if (ruler.zone != null) ...<Widget>[
            // Всё, что вне схемы (поля, текст), притушено так же, как пройденное.
            _dimmed('zone-dim-top', top: 0, height: zoneTop, color: dim),
            _dimmed('zone-dim-bottom', top: zoneBottom, height: height - zoneBottom, color: dim),
            _dimmed('zone-dim-left', top: zoneTop, height: zoneBottom - zoneTop, left: 0, width: left, color: dim),
            _dimmed(
              'zone-dim-right',
              top: zoneTop,
              height: zoneBottom - zoneTop,
              left: right,
              width: width - right,
              color: dim,
            ),
          ],
          // Всё, что уже сплетено, притушено: выше линейки при ходе сверху вниз, ниже неё при ходе снизу вверх.
          Positioned(
            key: const ValueKey<String>('ruler-dim'),
            left: left,
            width: right - left,
            top: ruler.isBottomUp ? ruler.bottom * scale : zoneTop,
            height: ruler.isBottomUp ? zoneBottom - ruler.bottom * scale : ruler.top * scale - zoneTop,
            child: IgnorePointer(child: ColoredBox(color: dim)),
          ),
          Positioned(
            key: const ValueKey<String>('ruler-band'),
            left: left,
            width: right - left,
            top: ruler.top * scale,
            height: ruler.height * scale,
            child: IgnorePointer(
              child: RowRing(child: ColoredBox(color: fill)),
            ),
          ),
          if (showZoneFrame)
            Positioned(
              key: const ValueKey<String>('zone-frame'),
              left: left,
              width: right - left,
              top: zoneTop,
              height: zoneBottom - zoneTop,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: context.tokens.accent.resolveFrom(context), width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dimmed(
    String key, {
    required double top,
    required double height,
    required Color color,
    double? left,
    double? width,
  }) => Positioned(
    key: ValueKey<String>(key),
    top: top,
    height: height < 0 ? 0 : height,
    left: left ?? 0,
    width: left == null ? this.width : (width! < 0 ? 0 : width),
    child: IgnorePointer(child: ColoredBox(color: color)),
  );
}

/// Картинка страницы из хранилища приложения.
class _PageImage extends StatefulWidget {
  const _PageImage({required this.files, required this.path});

  final FileStore files;
  final String path;

  @override
  State<_PageImage> createState() => _PageImageState();
}

class _PageImageState extends State<_PageImage> {
  late Future<Result<Uint8List>> _bytes = widget.files.read(widget.path);

  @override
  void didUpdateWidget(_PageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.files != widget.files) {
      _bytes = widget.files.read(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<Uint8List>>(
      future: _bytes,
      builder: (context, snapshot) {
        final Uint8List? data = snapshot.data?.valueOrNull;
        if (data != null) {
          return Image.memory(
            data,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) => const _ImageProblem(),
          );
        }
        if (snapshot.hasData) {
          return const _ImageProblem();
        }
        return const Center(child: CupertinoActivityIndicator());
      },
    );
  }
}

class _ImageProblem extends StatelessWidget {
  const _ImageProblem();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      AppLocalizations.of(context).bookWorkImageFailed,
      textAlign: TextAlign.center,
      style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
    ),
  );
}
