import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/palette/palette_snapshot.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/pattern_generation/pattern_generator.dart';
import 'package:beading/domain/pattern_generation/pattern_template.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/grid_pattern/grid_pattern_view.dart';
import 'package:beading/presentation/grid_pattern/grid_thumbnail.dart';
import 'package:beading/presentation/grid_pattern/grid_view_options.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/pattern_template/pattern_template_cubit.dart';
import 'package:beading/presentation/pattern_template/pattern_template_labels.dart';
import 'package:beading/presentation/pattern_template/pattern_template_state.dart';
import 'package:beading/presentation/pattern_template/template_color_sheet.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/color_swatch.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Экран «Узор по шаблону»: галерея, параметры, живой предпросмотр и сохранение. Закрывается с id нового проекта.
class PatternTemplateScreen extends StatefulWidget {
  const PatternTemplateScreen({super.key});

  /// Адрес экрана в роутере.
  static const String routePath = '/generate/template';

  static const List<Technique> techniques = <Technique>[
    Technique.loom,
    Technique.peyote,
    Technique.brick,
    Technique.square,
  ];

  @override
  State<PatternTemplateScreen> createState() => _PatternTemplateScreenState();
}

class _PatternTemplateScreenState extends State<PatternTemplateScreen> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _defaultName(AppLocalizations l10n, PatternTemplateState state) =>
      l10n.templateDefaultName(state.params.kind.label(l10n), state.params.width, state.params.height);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocConsumer<PatternTemplateCubit, PatternTemplateState>(
      // Название живёт в поле ввода и на экране не рисуется: перестраивать всё на каждый символ незачем.
      buildWhen: (previous, current) => previous.name == current.name,
      listenWhen: (previous, current) => current.projectId != null && previous.projectId == null,
      listener: (context, state) => Navigator.of(context).maybePop(state.projectId),
      builder: (context, state) {
        final PatternTemplateCubit cubit = context.read<PatternTemplateCubit>();
        final bool canSave = state.preview != null && !state.saving && state.projectId == null;
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(l10n.templateTitle),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: state.saving ? null : () => Navigator.of(context).maybePop(),
              child: Text(l10n.templateCancel),
            ),
            trailing: CupertinoButton(
              key: const ValueKey<String>('template-save'),
              padding: EdgeInsets.zero,
              onPressed: canSave ? () => cubit.save(fallbackName: _defaultName(l10n, state)) : null,
              child: state.saving
                  ? Semantics(label: l10n.templateSaving, child: const CupertinoActivityIndicator())
                  : Text(l10n.templateSave),
            ),
          ),
          child: SafeArea(
            child: switch (state.status) {
              TemplateStatus.loading => const Center(child: CupertinoActivityIndicator()),
              TemplateStatus.failure => _Failure(problem: state.problem, onRetry: cubit.start),
              TemplateStatus.ready => _Content(
                state: state,
                nameController: _name,
                defaultName: _defaultName(l10n, state),
              ),
            },
          ),
        );
      },
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.problem, required this.onRetry});

  final TemplateProblem? problem;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.tokens.spacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ProblemLine(text: templateProblemText(l10n, problem ?? TemplateProblem.catalogUnavailable)),
            CupertinoButton(
              key: const ValueKey<String>('template-retry'),
              minimumSize: Size.square(context.tokens.minTapTarget),
              onPressed: onRetry,
              child: Text(l10n.templateRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ошибка: значок и текст, цвет не единственный признак.
class _ProblemLine extends StatelessWidget {
  const _ProblemLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final Color color = CupertinoColors.systemRed.resolveFrom(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(AppIcons.warning, color: color, size: 20),
          SizedBox(width: context.tokens.spacing.s),
          Flexible(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.nameController, required this.defaultName});

  final PatternTemplateState state;
  final TextEditingController nameController;
  final String defaultName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PatternTemplateCubit cubit = context.read<PatternTemplateCubit>();
    final AppTokensData tokens = context.tokens;
    final TemplateParams p = state.params;
    // Высота предпросмотра зависит от свободного места: с клавиатурой или в узком окне он ужимается, а не выдавливает список.
    final MediaQueryData media = MediaQuery.of(context);
    final double previewHeight = ((media.size.height - media.viewInsets.bottom) * 0.28).clamp(96.0, 220.0);
    // Предпросмотр закреплён над прокруткой: параметры ниже, а результат всегда на виду. На широком окне — по центру.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(tokens.spacing.l, tokens.spacing.m, tokens.spacing.l, 0),
              child: _Preview(state: state, height: previewHeight),
            ),
            if (state.problem case final TemplateProblem problem when state.status == TemplateStatus.ready)
              Padding(
                padding: EdgeInsets.only(top: tokens.spacing.m, left: tokens.spacing.l, right: tokens.spacing.l),
                child: _ProblemLine(text: templateProblemText(l10n, problem)),
              ),
            Expanded(
              child: ListView(
                children: <Widget>[
                  CupertinoListSection.insetGrouped(
                    header: Text(l10n.templateSectionKind),
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.all(tokens.spacing.m),
                        child: _Gallery(state: state),
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    header: Text(l10n.templateSectionSize),
                    children: <Widget>[
                      _StepperTile(
                        label: l10n.templateWidth,
                        value: p.width,
                        min: TemplateParams.minSide,
                        max: TemplateParams.maxWidth,
                        onChanged: (v) => cubit.setParams(p.copyWith(width: v)),
                      ),
                      _StepperTile(
                        label: l10n.templateHeight,
                        value: p.height,
                        min: TemplateParams.minSide,
                        max: TemplateParams.maxHeight,
                        step: 5,
                        onChanged: (v) => cubit.setParams(p.copyWith(height: v)),
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    header: Text(l10n.templateSectionTechnique),
                    children: <Widget>[
                      _ChoiceTile(
                        title: l10n.templateSectionTechnique,
                        labels: <String>[for (final Technique t in PatternTemplateScreen.techniques) t.label(l10n)],
                        selected: PatternTemplateScreen.techniques.indexOf(p.technique).clamp(0, 3),
                        onSelected: (i) => cubit.setParams(p.copyWith(technique: PatternTemplateScreen.techniques[i])),
                      ),
                      _ChoiceTile(
                        title: l10n.templateSectionBead,
                        labels: <String>[for (final BeadSize b in BeadSize.values) b.label(l10n)],
                        selected: BeadSize.values.indexOf(p.bead),
                        onSelected: (i) => cubit.setParams(p.copyWith(bead: BeadSize.values[i])),
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    header: Text(l10n.templateSectionParams),
                    children: _paramRows(context, state, cubit),
                  ),
                  CupertinoListSection.insetGrouped(
                    header: Text(l10n.templateSectionColors),
                    children: _colorRows(context, state, cubit),
                  ),
                  CupertinoListSection.insetGrouped(
                    header: Text(l10n.templateSectionSymmetry),
                    footer: p.isShifted && p.symmetry != PatternSymmetry.none
                        ? Text(l10n.templateSymmetryApproximate, key: const ValueKey<String>('template-symmetry-note'))
                        : null,
                    children: <Widget>[
                      _ChoiceTile(
                        title: l10n.templateSectionSymmetry,
                        labels: <String>[for (final PatternSymmetry s in PatternSymmetry.values) s.label(l10n)],
                        selected: p.symmetry.index,
                        onSelected: (i) => cubit.setParams(p.copyWith(symmetry: PatternSymmetry.values[i])),
                      ),
                    ],
                  ),
                  CupertinoListSection.insetGrouped(
                    header: Text(l10n.templateSectionName),
                    children: <Widget>[
                      CupertinoListTile(
                        title: CupertinoTextField.borderless(
                          key: const ValueKey<String>('template-name'),
                          controller: nameController,
                          placeholder: defaultName,
                          maxLength: 80,
                          padding: EdgeInsets.zero,
                          onChanged: cubit.setName,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _paramRows(BuildContext context, PatternTemplateState state, PatternTemplateCubit cubit) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TemplateParams p = state.params;
    Widget axis() => _ChoiceTile(
      title: l10n.templateAxis,
      labels: <String>[l10n.templateAxisX, l10n.templateAxisY],
      selected: p.axis.index,
      onSelected: (i) => cubit.setParams(p.copyWith(axis: PatternAxis.values[i])),
    );
    Widget number(String label, int value, int min, int max, TemplateParams Function(int) change) => _StepperTile(
      label: label,
      value: value,
      min: min,
      max: max,
      onChanged: (v) => cubit.setParams(change(v)),
    );
    return switch (p.kind) {
      TemplateKind.stripes => <Widget>[
        number(
          l10n.templateStripeWidth,
          p.stripeWidth,
          1,
          TemplateParams.maxStripeWidth,
          (v) => p.copyWith(stripeWidth: v),
        ),
        axis(),
      ],
      TemplateKind.zigzag => <Widget>[
        number(l10n.templateAmplitude, p.amplitude, 1, 12, (v) => p.copyWith(amplitude: v)),
        number(l10n.templateZigzagThickness, p.zigzagThickness, 1, 6, (v) => p.copyWith(zigzagThickness: v)),
        number(l10n.templateGap, p.gap, 0, 8, (v) => p.copyWith(gap: v)),
      ],
      TemplateKind.diamonds => <Widget>[
        number(l10n.templateDiamondSize, p.diamondSize, 1, 12, (v) => p.copyWith(diamondSize: v)),
      ],
      TemplateKind.checker => <Widget>[
        number(l10n.templateCellSize, p.cellSize, 1, 12, (v) => p.copyWith(cellSize: v)),
      ],
      TemplateKind.gradient => <Widget>[
        number(l10n.templateSteps, p.steps, 2, 24, (v) => p.copyWith(steps: v)),
        axis(),
      ],
      TemplateKind.border => <Widget>[
        number(l10n.templateBorderThickness, p.borderThickness, 1, 12, (v) => p.copyWith(borderThickness: v)),
      ],
    };
  }

  /// Цвета строками списка: образец, название, артикул; нажатие открывает системный лист выбора.
  List<Widget> _colorRows(BuildContext context, PatternTemplateState state, PatternTemplateCubit cubit) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int used = state.usedColors;
    return <Widget>[
      for (int i = 0; i < used && i < state.colors.length; i++)
        CupertinoListTile.notched(
          key: ValueKey<String>('template-color-$i'),
          leading: ColorSwatchView(rgb: state.colors[i].rgb, size: 28),
          title: Text(state.colors[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(l10n.templateColorSlot(i + 1)),
          additionalInfo: Text(state.colors[i].components.first.code),
          trailing: const CupertinoListTileChevron(),
          onTap: () async {
            final TemplateColorChoice? choice = await showTemplateColorSheet(
              context,
              catalog: state.catalog,
              removable: state.canRemoveColor,
            );
            if (!context.mounted || cubit.isClosed) return;
            switch (choice) {
              case TemplateColorPicked(:final PatternColor color):
                cubit.setColor(i, color);
              case TemplateColorRemoved():
                cubit.removeColor(i);
              case null:
                break;
            }
          },
        ),
      if (state.canAddColor)
        CupertinoListTile.notched(
          key: const ValueKey<String>('template-add-color'),
          leading: const Icon(AppIcons.add),
          title: Text(l10n.templateAddColor),
          onTap: () async {
            final TemplateColorChoice? choice = await showTemplateColorSheet(
              context,
              catalog: state.catalog,
              removable: false,
            );
            if (!context.mounted || cubit.isClosed) return;
            if (choice case TemplateColorPicked(:final PatternColor color)) cubit.addColor(color);
          },
        ),
    ];
  }
}

/// Живой предпросмотр: схема на сером поле, можно приблизить и двигать.
class _Preview extends StatelessWidget {
  const _Preview({required this.state, required this.height});

  final PatternTemplateState state;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final GeneratedPattern? preview = state.preview;
    final TemplateParams p = state.params;
    return Semantics(
      label: l10n.templatePreviewLabel(p.width, p.height),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.tokens.radius.l),
        child: ColoredBox(
          color: CupertinoColors.secondarySystemFill.resolveFrom(context),
          child: SizedBox(
            key: const ValueKey<String>('template-preview'),
            height: height,
            child: preview == null
                ? const SizedBox.expand()
                : GridPatternView(
                    // Новый ключ на каждый узор: вид заново вписывается в поле, а не остаётся с прежним зумом.
                    key: ValueKey<Object>(Object.hash(preview.grid, p.technique, p.bead)),
                    grid: preview.grid,
                    palette: PaletteSnapshot(preview.palette),
                    geometry: p.geometry,
                    metrics: p.bead,
                    options: const GridViewOptions(showGridLines: false),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.state});

  final PatternTemplateState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PatternTemplateCubit cubit = context.read<PatternTemplateCubit>();
    final AppTokensData tokens = context.tokens;
    // Подпись карточки растёт с размером шрифта, поэтому высота ленты считается от него.
    final double labelHeight = MediaQuery.textScalerOf(context).scale(14) * 1.4;
    return SizedBox(
      height: 92 + tokens.spacing.xs + labelHeight + 8,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          for (final TemplateKind kind in TemplateKind.values)
            Padding(
              padding: EdgeInsets.only(right: tokens.spacing.m),
              child: _GalleryCard(
                key: ValueKey<String>('template-${kind.name}'),
                label: kind.label(l10n),
                selected: state.params.kind == kind,
                sample: state.gallery[kind],
                params: state.params,
                onTap: () => cubit.selectKind(kind),
              ),
            ),
        ],
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.label,
    required this.selected,
    required this.sample,
    required this.params,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final GeneratedPattern? sample;
  final TemplateParams params;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final Color accent = CupertinoTheme.of(context).primaryColor;
    final GeneratedPattern? pattern = sample;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 96,
          child: Column(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(tokens.radius.m),
                  border: Border.all(color: selected ? accent : const Color(0x00000000), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radius.m - 2),
                  child: SizedBox.square(
                    dimension: 92,
                    child: pattern == null
                        ? const SizedBox.expand()
                        : GridThumbnail(
                            grid: pattern.grid,
                            palette: PaletteSnapshot(pattern.palette),
                            geometry: params.geometry,
                            metrics: params.bead,
                          ),
                  ),
                ),
              ),
              SizedBox(height: tokens.spacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка выбора из нескольких вариантов: текущее значение справа, нажатие открывает системный лист действий.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.title, required this.labels, required this.selected, required this.onSelected});

  final String title;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CupertinoListTile.notched(
      title: Text(title),
      // Значение под названием, а не справа: при крупном шрифте оно переносится, а не вылезает за край.
      subtitle: Text(labels[selected]),
      trailing: const CupertinoListTileChevron(),
      onTap: () => showCupertinoModalPopup<void>(
        context: context,
        builder: (sheetContext) => CupertinoActionSheet(
          title: Text(title),
          actions: <Widget>[
            for (int i = 0; i < labels.length; i++)
              CupertinoActionSheetAction(
                isDefaultAction: i == selected,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  onSelected(i);
                },
                child: Text(labels[i]),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: Text(l10n.templateCancel),
          ),
        ),
      ),
    );
  }
}

/// Строка с числом и кнопками «−» и «+» (тач-зона 44 pt).
class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final double target = context.tokens.minTapTarget;
    return Semantics(
      // Для VoiceOver это один регулируемый элемент, как системный степпер: «увеличить» и «уменьшить».
      label: label,
      value: '$value',
      increasedValue: '${(value + step).clamp(min, max)}',
      decreasedValue: '${(value - step).clamp(min, max)}',
      onIncrease: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
      onDecrease: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
      child: ExcludeSemantics(
        child: CupertinoListTile(
          title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
          // Нажатие на строку открывает системное колесо значений: до нужного числа без десятков нажатий на «+».
          onTap: () => _pickValue(context),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CupertinoButton(
                key: ValueKey<String>('minus-$label'),
                minimumSize: Size.square(target),
                padding: EdgeInsets.zero,
                onPressed: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
                child: Semantics(label: '${l10n.templateValueMinus}: $label', child: const Icon(AppIcons.minus)),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44),
                child: Text(
                  '$value',
                  key: ValueKey<String>('value-$label'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
              CupertinoButton(
                key: ValueKey<String>('plus-$label'),
                minimumSize: Size.square(target),
                padding: EdgeInsets.zero,
                onPressed: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
                child: Semantics(label: '${l10n.templateValuePlus}: $label', child: const Icon(AppIcons.plus)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickValue(BuildContext context) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    int chosen = value;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(sheetContext),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  key: const ValueKey<String>('value-picker-done'),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(l10n.templateDone),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(initialItem: value - min),
                  onSelectedItemChanged: (index) => chosen = min + index,
                  children: <Widget>[for (int v = min; v <= max; v++) Center(child: Text('$v'))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    if (chosen != value) onChanged(chosen);
  }
}
