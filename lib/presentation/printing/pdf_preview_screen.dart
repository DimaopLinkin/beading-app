import 'dart:async';
import 'dart:typed_data';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/image_pattern/pdf_rasterizer.dart';
import 'package:beading/domain/sharing/file_sharer.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Просмотр готового PDF перед печатью (T81): листайте страницы, щипком увеличивайте, «Поделиться» — справа вверху.
class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({
    required this.pdf,
    required this.fileName,
    required this.rasterizer,
    required this.fileSharer,
    super.key,
  });

  final Uint8List pdf;
  final String fileName;
  final PdfRasterizer rasterizer;
  final FileSharer fileSharer;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  final PageController _controller = PageController();
  final Map<int, Future<ProcessedImage?>> _pages = <int, Future<ProcessedImage?>>{};
  int _count = 0;
  int _page = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final Result<int> count = await widget.rasterizer.pageCount(widget.pdf);
    if (!mounted) return;
    setState(() {
      _count = count.valueOrNull ?? 0;
      _failed = _count == 0;
    });
  }

  Future<ProcessedImage?> _render(int index) => _pages.putIfAbsent(index, () async {
    final Result<List<ProcessedImage>> result = await widget.rasterizer.render(widget.pdf, <int>[index], scale: 1.5);
    return result.valueOrNull?.single;
  });

  Future<void> _share(BuildContext buttonContext) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final RenderObject? box = buttonContext.findRenderObject();
    ShareOrigin? origin;
    if (box is RenderBox && box.hasSize) {
      final Offset topLeft = box.localToGlobal(Offset.zero);
      origin = ShareOrigin(left: topLeft.dx, top: topLeft.dy, width: box.size.width, height: box.size.height);
    }
    final Result<void> shared = await widget.fileSharer.shareFile(
      bytes: widget.pdf,
      fileName: widget.fileName,
      origin: origin,
    );
    if (!mounted || shared.isSuccess) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.actionFailedTitle),
        content: Text(l10n.shareFailed),
        actions: <Widget>[
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonOk),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_count == 0 ? l10n.printPreviewTitle : l10n.printPreviewPage(_page + 1, _count)),
        trailing: Builder(
          builder: (buttonContext) => CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.square(tokens.minTapTarget),
            onPressed: () => unawaited(_share(buttonContext)),
            child: const Icon(AppIcons.share, semanticLabel: 'Поделиться'),
          ),
        ),
      ),
      child: SafeArea(
        child: _failed
            ? Center(child: Text(l10n.flossPrintFailed))
            : _count == 0
            ? const Center(child: CupertinoActivityIndicator())
            : PageView.builder(
                controller: _controller,
                itemCount: _count,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => FutureBuilder<ProcessedImage?>(
                  future: _render(index),
                  builder: (context, snapshot) {
                    final ProcessedImage? image = snapshot.data;
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    if (image == null) return Center(child: Text(l10n.flossPrintFailed));
                    return InteractiveViewer(
                      maxScale: 8,
                      child: Center(
                        child: Image.memory(
                          image.png,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => Text(l10n.flossPrintFailed),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
