import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/stitch/stitch_legend.dart';
import 'package:beading/presentation/grid_pattern/grid_colors.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/app_list_section.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

/// Легенда вышивки: по строке на цвет палитры. Образец со знаком, бренд и номер нити, название, сложения, сколько
/// стежков каждого вида. Касание строки подсвечивает цвет на схеме ([onSelect]), повторное касание снимает подсветку.
/// Если легенду строили с расчётом мулине, в строке есть и число мотков.
class StitchLegendView extends StatelessWidget {
  const StitchLegendView({
    required this.entries,
    this.selected,
    this.onSelect,
    this.showUnused = false,
    super.key,
  });

  final List<StitchLegendEntry> entries;

  /// Значение сетки подсвеченного цвета.
  final int? selected;

  /// Касание строки: значение сетки цвета, а `null` — подсветку снять.
  final ValueChanged<int?>? onSelect;

  /// Показывать ли цвета, у которых нет ни одного стежка.
  final bool showUnused;

  /// «DMC 310» или «DMC 310 + 3865» у смешанной нити (бренд не повторяется, если он у частей один).
  static String threadLabel(PatternColor color) {
    final List<CatalogRef> parts = color.components;
    final String brand = parts.first.brand;
    if (parts.every((p) => p.brand == brand)) return '$brand ${parts.map((p) => p.code).join(' + ')}';
    return parts.map((p) => '${p.brand} ${p.code}').join(' + ');
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<StitchLegendEntry> shown = <StitchLegendEntry>[
      for (final StitchLegendEntry e in entries)
        if (showUnused || !e.isUnused) e,
    ];
    if (shown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(l10n.stitchLegendEmpty)),
      );
    }
    return AppListSection(
      children: <Widget>[
        for (final StitchLegendEntry entry in shown)
          _LegendRow(
            entry: entry,
            selected: selected == entry.gridValue,
            onTap: onSelect == null ? null : () => onSelect!(selected == entry.gridValue ? null : entry.gridValue),
          ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.entry, required this.selected, required this.onTap});

  final StitchLegendEntry entry;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final PatternColor color = entry.color;
    final NumberFormat oneDecimal = NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toString(),
      decimalDigits: 1,
    );
    final List<String> details = <String>[
      l10n.stitchLegendCrossStrands(entry.spec.crossStrands),
      if (entry.partials > 0) l10n.stitchLegendPartials(entry.partials),
      if (entry.backstitchLength > 0) ...<String>[
        l10n.stitchLegendBackstitch(oneDecimal.format(entry.backstitchLength)),
        l10n.stitchLegendBackStrands(entry.spec.backstitchStrands),
      ],
      if (entry.knots > 0) l10n.stitchLegendKnots(entry.knots),
      if (entry.skeins != null) l10n.flossSkeins(entry.skeins!),
    ];
    final Color accent = tokens.accent.resolveFrom(context);
    return Semantics(
      selected: selected,
      value: selected ? l10n.stitchLegendHighlighted : null,
      child: CupertinoListTile.notched(
        key: ValueKey<String>('legend-${entry.gridValue}'),
        backgroundColor: selected ? accent.withValues(alpha: 0.14) : null,
        leading: _Swatch(color: color),
        title: Text(StitchLegendView.threadLabel(color), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${color.name}\n${details.join(' · ')}', maxLines: 3, overflow: TextOverflow.ellipsis),
        additionalInfo: Text(l10n.stitchLegendCrosses(entry.crosses)),
        trailing: selected ? Icon(CupertinoIcons.checkmark_alt, size: 18, color: accent) : null,
        onTap: onTap,
      ),
    );
  }
}

/// Образец нити со знаком палитры: знак чёрный или белый по яркости заливки, как на схеме.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final PatternColor color;

  @override
  Widget build(BuildContext context) {
    final Color fill = Color.fromARGB(255, color.rgb.r, color.rgb.g, color.rgb.b);
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        ColorSwatchView(rgb: color.rgb, size: 30, radius: 7),
        if (color.symbol != null)
          ExcludeSemantics(
            child: Text(
              color.symbol!,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: GridColors.symbolOn(fill), height: 1),
            ),
          ),
      ],
    );
  }
}
