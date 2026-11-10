import 'dart:async';

import 'package:beading/core/result.dart';
import 'package:beading/domain/catalog/catalog_color.dart';
import 'package:beading/domain/catalog/catalog_material.dart';
import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/nearest_color_matcher.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/glass/glass_sheet.dart';
import 'package:flutter/cupertino.dart';

/// Итог листа цвета: новый цвет или удаление.
sealed class ColorSheetResult {
  const ColorSheetResult();
}

final class ColorChosen extends ColorSheetResult {
  const ColorChosen(this.color);

  final PatternColor color;
}

final class ColorDeleted extends ColorSheetResult {
  const ColorDeleted();
}

/// Показывает лист цвета. [initial] `null` — новый цвет; иначе правка цвета палитры (можно удалить).
Future<ColorSheetResult?> showColorSheet(
  BuildContext context, {
  required CatalogRepository catalog,
  PatternColor? initial,
}) => showCupertinoModalPopup<ColorSheetResult>(
  context: context,
  builder: (_) => Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ColorSheet(catalog: catalog, initial: initial),
    ),
  ),
);

/// Лист цвета: название, цвет ползунками, выбор из каталога с поиском по артикулу и ближайшие к текущему цвету.
class ColorSheet extends StatefulWidget {
  const ColorSheet({required this.catalog, this.initial, super.key});

  final CatalogRepository catalog;
  final PatternColor? initial;

  @override
  State<ColorSheet> createState() => _ColorSheetState();
}

class _ColorSheetState extends State<ColorSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initial?.name ?? '');
  late Rgb _rgb = widget.initial?.rgb ?? const Rgb(200, 60, 60);
  late List<CatalogRef> _components = widget.initial?.components ?? const <CatalogRef>[];
  late String? _finish = widget.initial?.finish;
  String _query = '';
  List<CatalogColor> _results = const <CatalogColor>[];
  List<CatalogColor> _nearest = const <CatalogColor>[];
  Timer? _debounce;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshNearest());
    unawaited(_search());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _refreshNearest() async {
    final Result<List<ColorMatch<CatalogColor>>> found = await widget.catalog.nearest(
      _rgb,
      material: CatalogMaterial.bead,
    );
    if (!mounted) return;
    setState(() => _nearest = found.valueOrNull?.map((m) => m.item).toList() ?? const <CatalogColor>[]);
  }

  Future<void> _search() async {
    final int token = ++_searchToken;
    final Result<List<CatalogColor>> found = await widget.catalog.search(
      query: _query,
      material: CatalogMaterial.bead,
    );
    if (!mounted || token != _searchToken) return;
    setState(() {
      final List<CatalogColor> all = found.valueOrNull ?? const <CatalogColor>[];
      _results = all.length > 30 ? all.sublist(0, 30) : all;
    });
  }

  void _onQuery(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => unawaited(_search()));
  }

  void _pick(CatalogColor color) {
    setState(() {
      _rgb = color.rgb;
      _components = <CatalogRef>[color.ref];
      _finish = color.finish;
      _name.text = color.name;
    });
    unawaited(_refreshNearest());
  }

  void _setChannel({int? r, int? g, int? b}) {
    setState(() {
      _rgb = Rgb(r ?? _rgb.r, g ?? _rgb.g, b ?? _rgb.b);
      // Ручной цвет больше не совпадает с позицией каталога.
      _components = const <CatalogRef>[];
      _finish = null;
    });
    unawaited(_refreshNearest());
  }

  PatternColor _result(AppLocalizations l10n) {
    final String typed = _name.text.trim();
    final String fallback = _components.isEmpty ? l10n.colorSheetTitle : _components.first.code;
    return PatternColor(
      rgb: _rgb,
      name: typed.isEmpty ? fallback : typed,
      // Своему цвету позиция каталога не нужна, но схема требует одну: берём ближайшую.
      components: _components.isNotEmpty
          ? _components
          : (_nearest.isNotEmpty
                ? <CatalogRef>[_nearest.first.ref]
                : const <CatalogRef>[CatalogRef(brand: '', code: '')]),
      finish: _finish,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double gap = context.tokens.spacing.m;
    final TextStyle base = CupertinoTheme.of(context).textTheme.textStyle;
    return GlassSheet(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(l10n.colorSheetTitle, style: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                CupertinoButton(
                  key: const ValueKey<String>('color-done'),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(ColorChosen(_result(l10n))),
                  child: Text(l10n.colorSheetDone),
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Container(
                  key: const ValueKey<String>('color-preview'),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, _rgb.r, _rgb.g, _rgb.b),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  child: CupertinoTextField(
                    key: const ValueKey<String>('color-name'),
                    controller: _name,
                    placeholder: l10n.colorSheetName,
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            _Channel(
              keyName: 'red',
              label: l10n.colorSheetRed,
              value: _rgb.r,
              onChanged: (v) => _setChannel(r: v),
            ),
            _Channel(
              keyName: 'green',
              label: l10n.colorSheetGreen,
              value: _rgb.g,
              onChanged: (v) => _setChannel(g: v),
            ),
            _Channel(
              keyName: 'blue',
              label: l10n.colorSheetBlue,
              value: _rgb.b,
              onChanged: (v) => _setChannel(b: v),
            ),
            if (_nearest.isNotEmpty) ...<Widget>[
              SizedBox(height: gap),
              Text(l10n.colorSheetNearest, style: base.copyWith(fontWeight: FontWeight.w600)),
              SizedBox(height: context.tokens.spacing.s),
              for (final CatalogColor color in _nearest)
                _CatalogRow(color: color, onTap: () => _pick(color), prefix: 'near'),
            ],
            SizedBox(height: gap),
            Text(l10n.colorSheetCatalog, style: base.copyWith(fontWeight: FontWeight.w600)),
            SizedBox(height: context.tokens.spacing.s),
            CupertinoSearchTextField(
              key: const ValueKey<String>('color-search'),
              placeholder: l10n.colorSheetSearch,
              onChanged: _onQuery,
            ),
            SizedBox(height: context.tokens.spacing.s),
            if (_results.isEmpty)
              Padding(
                padding: EdgeInsets.all(gap),
                child: Text(l10n.colorSheetNothing, textAlign: TextAlign.center),
              )
            else
              for (final CatalogColor color in _results)
                _CatalogRow(color: color, onTap: () => _pick(color), prefix: 'cat'),
            if (widget.initial != null) ...<Widget>[
              SizedBox(height: gap),
              CupertinoButton(
                key: const ValueKey<String>('color-delete'),
                onPressed: () => Navigator.of(context).pop(const ColorDeleted()),
                child: Text(
                  l10n.colorSheetDelete,
                  style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context)),
                ),
              ),
              Text(
                l10n.colorSheetDeleteHint,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Channel extends StatelessWidget {
  const _Channel({required this.keyName, required this.label, required this.value, required this.onChanged});

  final String keyName;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      SizedBox(width: 84, child: Text(label)),
      Expanded(
        child: CupertinoSlider(
          key: ValueKey<String>('color-$keyName'),
          value: value.toDouble(),
          max: 255,
          divisions: 255,
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
      SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.end)),
    ],
  );
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({required this.color, required this.onTap, required this.prefix});

  final CatalogColor color;
  final VoidCallback onTap;
  final String prefix;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey<String>('$prefix-${color.id}'),
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: context.tokens.minTapTarget),
      child: Row(
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color.fromARGB(255, color.rgb.r, color.rgb.g, color.rgb.b),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('${color.code} · ${color.name}', maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );
}
