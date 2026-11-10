import 'dart:typed_data';

import 'package:beading/core/result.dart';
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
  const PageCanvas({required this.files, required this.page, required this.ruler, required this.width, super.key});

  final FileStore files;
  final ImagePatternPage page;
  final RulerState ruler;

  /// Ширина, в которую вписана страница (при зуме 1×).
  final double width;

  /// Высота страницы при ширине [width].
  double get height => width * page.height / page.width;

  @override
  Widget build(BuildContext context) {
    final double scale = width / page.width;
    final Color fill = RulerColors.fill(context, ruler.highlight);
    final Color dim = context.tokens.rowDim.resolveFrom(context);
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
          // Всё, что выше линейки, уже сплетено: притушено.
          Positioned(
            key: const ValueKey<String>('ruler-dim'),
            left: 0,
            right: 0,
            top: 0,
            height: ruler.top * scale,
            child: IgnorePointer(child: ColoredBox(color: dim)),
          ),
          Positioned(
            key: const ValueKey<String>('ruler-band'),
            left: 0,
            right: 0,
            top: ruler.top * scale,
            height: ruler.height * scale,
            child: IgnorePointer(
              child: RowRing(child: ColoredBox(color: fill)),
            ),
          ),
        ],
      ),
    );
  }
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
