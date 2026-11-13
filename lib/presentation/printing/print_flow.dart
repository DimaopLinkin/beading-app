import 'dart:async';

import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/pdf_rasterizer.dart';
import 'package:beading/domain/printing/print_layout.dart';
import 'package:beading/domain/printing/print_options.dart';
import 'package:beading/domain/printing/use_cases/export_pattern_pdf.dart';
import 'package:beading/domain/sharing/file_sharer.dart';
import 'package:beading/domain/sharing/text_sharer.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/printing/pdf_preview_screen.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';

/// Печать схемы (T76, T80): настройки в листе, сборка PDF и лист «Поделиться». Общая для экранов «Мулине» и мастера.
///
/// [summary] — размер схемы для счёта страниц, [build] запоминает настройки и собирает PDF. [origin] — кнопка, от
/// которой на iPad и Mac открывается лист «Поделиться».
Future<void> runPrintFlow(
  BuildContext context, {
  required Future<PrintOptions> Function() loadOptions,
  required Future<PrintSummary?> Function() summary,
  required Future<Result<PatternPdf>> Function(PrintOptions options) build,
  required FileSharer fileSharer,
  PdfRasterizer? rasterizer,
  GlobalKey? originKey,
}) async {
  final PrintOptions initial = await loadOptions();
  final PrintSummary? info = await summary();
  if (!context.mounted || info == null) return;
  final PrintOptions? chosen = await showCupertinoSheet<PrintOptions>(
    context: context,
    builder: (_) => _PrintSheet(initial: initial, summary: info),
  );
  if (chosen == null || !context.mounted) return;
  final AppLocalizations l10n = AppLocalizations.of(context);
  unawaited(
    showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(l10n.printBuilding),
        content: const Padding(padding: EdgeInsets.only(top: 12), child: CupertinoActivityIndicator()),
      ),
    ),
  );
  final Result<PatternPdf> pdf = await build(chosen);
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  Result<void> shared = const Success<void>(null);
  final PdfRasterizer? viewer = rasterizer;
  if (viewer != null && pdf is Success<PatternPdf>) {
    final PatternPdf value = pdf.value;
    // Сначала смотрим, потом «Поделиться» из просмотра.
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => PdfPreviewScreen(
          pdf: value.bytes,
          fileName: value.fileName,
          rasterizer: viewer,
          fileSharer: fileSharer,
        ),
      ),
    );
    return;
  }
  if (pdf case Success<PatternPdf>(:final PatternPdf value)) {
    final RenderObject? box = originKey?.currentContext?.findRenderObject();
    ShareOrigin? origin;
    if (box is RenderBox && box.hasSize) {
      final Offset topLeft = box.localToGlobal(Offset.zero);
      origin = ShareOrigin(left: topLeft.dx, top: topLeft.dy, width: box.size.width, height: box.size.height);
    }
    shared = await fileSharer.shareFile(bytes: value.bytes, fileName: value.fileName, origin: origin);
  }
  if (!context.mounted || (pdf.isSuccess && shared.isSuccess)) return;
  await showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(l10n.actionFailedTitle),
      content: Text(pdf.isSuccess ? l10n.shareFailed : l10n.flossPrintFailed),
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

class _PrintSheet extends StatefulWidget {
  const _PrintSheet({required this.initial, required this.summary});

  final PrintOptions initial;
  final PrintSummary summary;

  @override
  State<_PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends State<_PrintSheet> {
  late PrintOptions _options = widget.initial;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final PrintLayout layout = PrintLayout(_options.paper);
    final int sheets = layout.tiles(columns: widget.summary.columns, rows: widget.summary.rows).length;
    final int legend = LegendLayout.pageCount(widget.summary.colors);
    final int colors = widget.summary.colors;
    final String slotsExample = colors <= _options.slotsPerRack
        ? l10n.printSlotsOne(colors)
        : l10n.printSlotsMany((colors + _options.slotsPerRack - 1) ~/ _options.slotsPerRack, _options.slotsPerRack);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: Text(l10n.printSheetTitle),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.square(tokens.minTapTarget),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.spacing.l),
          children: <Widget>[
            Text(l10n.printPaper, style: base.copyWith(fontSize: 13, color: secondary)),
            SizedBox(height: tokens.spacing.xs),
            CupertinoSlidingSegmentedControl<PrintPaper>(
              key: const ValueKey<String>('print-paper'),
              groupValue: _options.paper,
              children: <PrintPaper, Widget>{
                for (final PrintPaper p in PrintPaper.values)
                  p: Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.spacing.s),
                    child: Text(p.name.toUpperCase()),
                  ),
              },
              onValueChanged: (value) {
                if (value != null) setState(() => _options = _options.copyWith(paper: value));
              },
            ),
            SizedBox(height: tokens.spacing.l),
            Text(
              l10n.printPages(sheets + legend, sheets, legend),
              key: const ValueKey<String>('print-pages'),
              style: base.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: tokens.spacing.xs),
            Text(l10n.printScaleHint, style: base.copyWith(fontSize: 13, color: secondary)),
            SizedBox(height: tokens.spacing.l),
            Text(l10n.printSlots, style: base.copyWith(fontSize: 13, color: secondary)),
            SizedBox(height: tokens.spacing.xs),
            Row(
              children: <Widget>[
                CupertinoButton(
                  key: const ValueKey<String>('print-slots-minus'),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.square(tokens.minTapTarget),
                  onPressed: _options.slotsPerRack <= PrintOptions.minSlots
                      ? null
                      : () => setState(() => _options = _options.copyWith(slotsPerRack: _options.slotsPerRack - 5)),
                  child: const Icon(CupertinoIcons.minus_circle),
                ),
                Expanded(
                  child: Text(
                    '${_options.slotsPerRack}',
                    key: const ValueKey<String>('print-slots'),
                    textAlign: TextAlign.center,
                    style: base.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                CupertinoButton(
                  key: const ValueKey<String>('print-slots-plus'),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.square(tokens.minTapTarget),
                  onPressed: _options.slotsPerRack >= PrintOptions.maxSlots
                      ? null
                      : () => setState(() => _options = _options.copyWith(slotsPerRack: _options.slotsPerRack + 5)),
                  child: const Icon(CupertinoIcons.plus_circle),
                ),
              ],
            ),
            Text(
              '${l10n.printSlotsHint}\n$slotsExample',
              style: base.copyWith(fontSize: 13, color: secondary),
            ),
            SizedBox(height: tokens.spacing.xl),
            CupertinoButton.filled(
              key: const ValueKey<String>('print-build'),
              onPressed: () => Navigator.of(context).pop(_options),
              child: Text(l10n.printBuild),
            ),
          ],
        ),
      ),
    );
  }
}
