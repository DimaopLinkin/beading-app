import 'package:beading/domain/grid/fabric.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/presentation/editor/new_stitch_cubit.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/fabric_labels.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Лист создания схемы вышивки: канва и размер. Закрывается с id созданного проекта.
class NewStitchScreen extends StatelessWidget {
  const NewStitchScreen({super.key});

  static const String routePath = '/editor/new-stitch';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocConsumer<NewStitchCubit, NewStitchState>(
      listenWhen: (before, after) => before.projectId == null && after.projectId != null,
      listener: (context, state) => Navigator.of(context).maybePop(state.projectId),
      builder: (context, state) {
        final NewStitchCubit cubit = context.read<NewStitchCubit>();
        final double gap = context.tokens.spacing.m;
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(l10n.newStitchTitle),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: state.creating ? null : () => Navigator.of(context).maybePop(),
              child: Text(l10n.newGridCancel),
            ),
            trailing: CupertinoButton(
              key: const ValueKey<String>('new-stitch-create'),
              padding: EdgeInsets.zero,
              onPressed: state.creating || !state.validSize ? null : cubit.create,
              child: Text(l10n.newGridCreate),
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.all(context.tokens.spacing.l),
              children: <Widget>[
                CupertinoTextField(
                  key: const ValueKey<String>('new-stitch-name'),
                  placeholder: l10n.newGridName,
                  onChanged: cubit.setName,
                ),
                SizedBox(height: gap),
                CupertinoListSection.insetGrouped(
                  margin: EdgeInsets.zero,
                  children: <Widget>[
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('new-stitch-fabric'),
                      title: Text(l10n.imageWizardFabric),
                      additionalInfo: Text(fabricLabel(l10n, state.fabric)),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () async {
                        final Fabric? chosen = await _pick<Fabric>(
                          context,
                          title: l10n.imageWizardFabric,
                          values: fabricChoices(state.fabric),
                          label: (fabric) => fabricLabel(l10n, fabric),
                          cancel: l10n.newGridCancel,
                        );
                        if (chosen != null) cubit.setFabric(chosen);
                      },
                    ),
                    CupertinoListTile.notched(
                      key: const ValueKey<String>('new-stitch-fabric-color'),
                      title: Text(l10n.imageWizardFabricColor),
                      leading: _Swatch(state.fabric.color),
                      additionalInfo: Text(canvasName(l10n, state.fabric.color)),
                      trailing: const CupertinoListTileChevron(),
                      onTap: () async {
                        final Rgb? chosen = await _pick<Rgb>(
                          context,
                          title: l10n.imageWizardFabricColor,
                          values: canvasColors,
                          label: (color) => canvasName(l10n, color),
                          cancel: l10n.newGridCancel,
                        );
                        if (chosen != null) cubit.setFabricColor(chosen);
                      },
                    ),
                  ],
                ),
                SizedBox(height: gap),
                CupertinoSlidingSegmentedControl<StitchSizeUnit>(
                  groupValue: state.unit,
                  children: <StitchSizeUnit, Widget>{
                    StitchSizeUnit.cells: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(l10n.newStitchUnitCells),
                    ),
                    StitchSizeUnit.cm: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(l10n.newStitchUnitCm),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value != null) cubit.setUnit(value);
                  },
                ),
                SizedBox(height: gap),
                _SizeRow(
                  keyPrefix: 'width',
                  label: state.unit == StitchSizeUnit.cells ? l10n.newStitchWidthCells : l10n.newStitchWidthCm,
                  unit: state.unit,
                  cells: state.width,
                  cm: state.widthCm,
                  onCells: cubit.setWidth,
                  onCm: cubit.setWidthCm,
                ),
                SizedBox(height: gap),
                _SizeRow(
                  keyPrefix: 'height',
                  label: state.unit == StitchSizeUnit.cells ? l10n.newStitchHeightCells : l10n.newStitchHeightCm,
                  unit: state.unit,
                  cells: state.height,
                  cm: state.heightCm,
                  onCells: cubit.setHeight,
                  onCm: cubit.setHeightCm,
                ),
                SizedBox(height: gap),
                Text(
                  state.validSize
                      ? l10n.newStitchSizeSummary(
                          '${state.width}',
                          '${state.height}',
                          _cm(state.widthCm),
                          _cm(state.heightCm),
                        )
                      : l10n.newStitchSizeInvalid(NewStitchState.maxSide),
                  key: const ValueKey<String>('new-stitch-size'),
                  style: TextStyle(
                    color: state.validSize
                        ? CupertinoColors.secondaryLabel.resolveFrom(context)
                        : CupertinoColors.systemRed.resolveFrom(context),
                  ),
                ),
                if (state.failed) ...<Widget>[
                  SizedBox(height: gap),
                  Text(l10n.newGridFailed, style: TextStyle(color: CupertinoColors.systemRed.resolveFrom(context))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static String _cm(double value) => value.toStringAsFixed(1).replaceAll('.', ',');
}

/// Системный выбор значения: нижний лист действий iOS.
Future<T?> _pick<T>(
  BuildContext context, {
  required String title,
  required List<T> values,
  required String Function(T value) label,
  required String cancel,
}) => showCupertinoModalPopup<T>(
  context: context,
  builder: (sheet) => CupertinoActionSheet(
    title: Text(title),
    actions: <Widget>[
      for (final T value in values)
        CupertinoActionSheetAction(onPressed: () => Navigator.of(sheet).pop(value), child: Text(label(value))),
    ],
    cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.of(sheet).pop(), child: Text(cancel)),
  ),
);

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Rgb color;

  @override
  Widget build(BuildContext context) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: Color.fromARGB(255, color.r, color.g, color.b),
      shape: BoxShape.circle,
      border: Border.all(color: CupertinoColors.separator.resolveFrom(context)),
    ),
  );
}

/// Размер по одной стороне: число в клетках или сантиметрах с кнопками «−» и «+».
class _SizeRow extends StatefulWidget {
  const _SizeRow({
    required this.keyPrefix,
    required this.label,
    required this.unit,
    required this.cells,
    required this.cm,
    required this.onCells,
    required this.onCm,
  });

  final String keyPrefix;
  final String label;
  final StitchSizeUnit unit;
  final int cells;
  final double cm;
  final ValueChanged<int> onCells;
  final ValueChanged<double> onCm;

  @override
  State<_SizeRow> createState() => _SizeRowState();
}

class _SizeRowState extends State<_SizeRow> {
  late final TextEditingController _controller = TextEditingController(text: _text());

  String _text() =>
      widget.unit == StitchSizeUnit.cells ? '${widget.cells}' : widget.cm.toStringAsFixed(1).replaceAll('.', ',');

  /// Число из поля; для сантиметров принимает и запятую.
  double? _parsed(String text) => double.tryParse(text.replaceAll(',', '.'));

  @override
  void didUpdateWidget(_SizeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool unitChanged = oldWidget.unit != widget.unit;
    final double? typed = _parsed(_controller.text);
    final bool same = widget.unit == StitchSizeUnit.cells
        ? typed?.round() == widget.cells && typed == typed?.roundToDouble()
        : typed != null && (typed - widget.cm).abs() < 0.05;
    // Набранный текст не трогаем, пока он и так равен значению (иначе «12,» превращалось бы в «12,0»).
    if (unitChanged || (!same && _controller.text.isNotEmpty)) _controller.text = _text();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _step(int delta) {
    if (widget.unit == StitchSizeUnit.cells) {
      widget.onCells(widget.cells + delta);
    } else {
      widget.onCm(widget.cm + delta);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String p = widget.keyPrefix;
    return Row(
      children: <Widget>[
        Expanded(child: Text(widget.label)),
        CupertinoButton(
          key: ValueKey<String>('$p-minus'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: widget.cells > NewStitchState.minSide ? () => _step(-1) : null,
          child: const Icon(CupertinoIcons.minus_circle),
        ),
        SizedBox(
          width: 72,
          child: CupertinoTextField(
            key: ValueKey<String>('$p-field'),
            controller: _controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.numberWithOptions(decimal: widget.unit == StitchSizeUnit.cm),
            // Пустое поле — «ещё не введено»: размер 0 недопустим, «Создать» недоступна.
            onChanged: (text) {
              final double? value = _parsed(text);
              if (widget.unit == StitchSizeUnit.cells) {
                widget.onCells(value?.round() ?? 0);
              } else {
                widget.onCm(value ?? 0);
              }
            },
          ),
        ),
        CupertinoButton(
          key: ValueKey<String>('$p-plus'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: widget.cells < NewStitchState.maxSide ? () => _step(1) : null,
          child: const Icon(CupertinoIcons.plus_circle),
        ),
      ],
    );
  }
}
