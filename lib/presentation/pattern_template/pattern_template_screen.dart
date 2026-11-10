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
import 'package:beading/presentation/widgets/min_tap_target.dart';
import 'package:beading/presentation/widgets/pill_chip.dart';
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
              child: state.saving ? const CupertinoActivityIndicator() : Text(l10n.templateSave),
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
    final double gap = tokens.spacing.m;
    // Предпросмотр закреплён над прокруткой: параметры ниже, а результат всегда на виду. На широком окне — по центру.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(tokens.spacing.l, tokens.spacing.m, tokens.spacing.l, 0),
              child: _Preview(state: state),
            ),
            if (state.problem case final TemplateProblem problem when state.status == TemplateStatus.ready)
              Padding(
                padding: EdgeInsets.only(top: gap, left: tokens.spacing.l, right: tokens.spacing.l),
                child: _ProblemLine(text: templateProblemText(l10n, problem)),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(tokens.spacing.l),
                children: <Widget>[
                  _Section(
                    title: l10n.templateSectionKind,
                    child: _Gallery(state: state),
                  ),
                  _Section(
                    title: l10n.templateSectionSize,
                    child: Column(
                      children: <Widget>[
                        _Stepper(
                          label: l10n.templateWidth,
                          value: p.width,
                          min: TemplateParams.minSide,
                          max: TemplateParams.maxWidth,
                          onChanged: (v) => cubit.setParams(p.copyWith(width: v)),
                        ),
                        _Stepper(
                          label: l10n.templateHeight,
                          value: p.height,
                          min: TemplateParams.minSide,
                          max: TemplateParams.maxHeight,
                          step: 5,
                          onChanged: (v) => cubit.setParams(p.copyWith(height: v)),
                        ),
                      ],
                    ),
                  ),
                  _Section(
                    title: l10n.templateSectionTechnique,
                    child: Wrap(
                      runSpacing: tokens.spacing.xs,
                      children: <Widget>[
                        for (final Technique t in PatternTemplateScreen.techniques)
                          PillChip(
                            label: t.label(l10n),
                            selected: p.technique == t,
                            onTap: () => cubit.setParams(p.copyWith(technique: t)),
                          ),
                      ],
                    ),
                  ),
                  _Section(
                    title: l10n.templateSectionBead,
                    child: Wrap(
                      runSpacing: tokens.spacing.xs,
                      children: <Widget>[
                        for (final BeadSize b in BeadSize.values)
                          PillChip(
                            label: b.label(l10n),
                            selected: p.bead == b,
                            onTap: () => cubit.setParams(p.copyWith(bead: b)),
                          ),
                      ],
                    ),
                  ),
                  _Section(
                    title: l10n.templateSectionParams,
                    child: Column(children: _paramRows(context, state, cubit)),
                  ),
                  _Section(
                    title: l10n.templateSectionColors,
                    child: _Colors(state: state),
                  ),
                  _Section(
                    title: l10n.templateSectionSymmetry,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Wrap(
                          runSpacing: tokens.spacing.xs,
                          children: <Widget>[
                            for (final PatternSymmetry sym in PatternSymmetry.values)
                              PillChip(
                                label: sym.label(l10n),
                                selected: p.symmetry == sym,
                                onTap: () => cubit.setParams(p.copyWith(symmetry: sym)),
                              ),
                          ],
                        ),
                        if (p.isShifted && p.symmetry != PatternSymmetry.none)
                          Padding(
                            padding: EdgeInsets.only(top: tokens.spacing.s),
                            child: Text(
                              l10n.templateSymmetryApproximate,
                              key: const ValueKey<String>('template-symmetry-note'),
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _Section(
                    title: l10n.templateSectionName,
                    child: CupertinoTextField(
                      key: const ValueKey<String>('template-name'),
                      controller: nameController,
                      placeholder: defaultName,
                      maxLength: 80,
                      onChanged: cubit.setName,
                    ),
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
    Widget axis() => _AxisPicker(
      value: p.axis,
      onChanged: (a) => cubit.setParams(p.copyWith(axis: a)),
    );
    return switch (p.kind) {
      TemplateKind.stripes => <Widget>[
        _Stepper(
          label: l10n.templateStripeWidth,
          value: p.stripeWidth,
          min: 1,
          max: TemplateParams.maxStripeWidth,
          onChanged: (v) => cubit.setParams(p.copyWith(stripeWidth: v)),
        ),
        axis(),
      ],
      TemplateKind.zigzag => <Widget>[
        _Stepper(
          label: l10n.templateAmplitude,
          value: p.amplitude,
          min: 1,
          max: 12,
          onChanged: (v) => cubit.setParams(p.copyWith(amplitude: v)),
        ),
        _Stepper(
          label: l10n.templateZigzagThickness,
          value: p.zigzagThickness,
          min: 1,
          max: 6,
          onChanged: (v) => cubit.setParams(p.copyWith(zigzagThickness: v)),
        ),
        _Stepper(
          label: l10n.templateGap,
          value: p.gap,
          min: 0,
          max: 8,
          onChanged: (v) => cubit.setParams(p.copyWith(gap: v)),
        ),
      ],
      TemplateKind.diamonds => <Widget>[
        _Stepper(
          label: l10n.templateDiamondSize,
          value: p.diamondSize,
          min: 1,
          max: 12,
          onChanged: (v) => cubit.setParams(p.copyWith(diamondSize: v)),
        ),
      ],
      TemplateKind.checker => <Widget>[
        _Stepper(
          label: l10n.templateCellSize,
          value: p.cellSize,
          min: 1,
          max: 12,
          onChanged: (v) => cubit.setParams(p.copyWith(cellSize: v)),
        ),
      ],
      TemplateKind.gradient => <Widget>[
        _Stepper(
          label: l10n.templateSteps,
          value: p.steps,
          min: 2,
          max: 24,
          onChanged: (v) => cubit.setParams(p.copyWith(steps: v)),
        ),
        axis(),
      ],
      TemplateKind.border => <Widget>[
        _Stepper(
          label: l10n.templateBorderThickness,
          value: p.borderThickness,
          min: 1,
          max: 12,
          onChanged: (v) => cubit.setParams(p.copyWith(borderThickness: v)),
        ),
      ],
    };
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.s),
          child,
        ],
      ),
    );
  }
}

/// Живой предпросмотр: схема на сером поле, можно приблизить и двигать.
class _Preview extends StatelessWidget {
  const _Preview({required this.state});

  final PatternTemplateState state;

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
            height: 200,
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

class _Colors extends StatelessWidget {
  const _Colors({required this.state});

  final PatternTemplateState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PatternTemplateCubit cubit = context.read<PatternTemplateCubit>();
    final AppTokensData tokens = context.tokens;
    final int used = state.usedColors;
    return Wrap(
      spacing: tokens.spacing.m,
      runSpacing: tokens.spacing.s,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (int i = 0; i < used && i < state.colors.length; i++)
          Semantics(
            button: true,
            label: '${l10n.templateColorSlot(i + 1)}: ${state.colors[i].name}',
            excludeSemantics: true,
            child: GestureDetector(
              key: ValueKey<String>('template-color-$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final TemplateColorChoice? choice = await showTemplateColorSheet(
                  context,
                  catalog: state.catalog,
                  removable: state.canRemoveColor,
                );
                switch (choice) {
                  case TemplateColorPicked(:final PatternColor color):
                    cubit.setColor(i, color);
                  case TemplateColorRemoved():
                    cubit.removeColor(i);
                  case null:
                    break;
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  MinTapTarget(child: ColorSwatchView(rgb: state.colors[i].rgb, size: 36)),
                  Text(
                    state.colors[i].components.first.code,
                    style: TextStyle(fontSize: 12, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                  ),
                ],
              ),
            ),
          ),
        if (state.canAddColor)
          CupertinoButton(
            key: const ValueKey<String>('template-add-color'),
            minimumSize: Size.square(tokens.minTapTarget),
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.s),
            onPressed: () async {
              final TemplateColorChoice? choice = await showTemplateColorSheet(
                context,
                catalog: state.catalog,
                removable: false,
              );
              if (choice case TemplateColorPicked(:final PatternColor color)) cubit.addColor(color);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(AppIcons.add, size: 18),
                SizedBox(width: tokens.spacing.xs),
                Flexible(child: Text(l10n.templateAddColor)),
              ],
            ),
          ),
      ],
    );
  }
}

class _AxisPicker extends StatelessWidget {
  const _AxisPicker({required this.value, required this.onChanged});

  final PatternAxis value;
  final ValueChanged<PatternAxis> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.templateAxis),
          SizedBox(height: tokens.spacing.xs),
          Wrap(
            runSpacing: tokens.spacing.xs,
            children: <Widget>[
              PillChip(
                label: l10n.templateAxisX,
                selected: value == PatternAxis.x,
                onTap: () => onChanged(PatternAxis.x),
              ),
              PillChip(
                label: l10n.templateAxisY,
                selected: value == PatternAxis.y,
                onTap: () => onChanged(PatternAxis.y),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Число с кнопками «−» и «+» (тач-зона 44 pt).
class _Stepper extends StatelessWidget {
  const _Stepper({
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
    final AppTokensData tokens = context.tokens;
    final double target = tokens.minTapTarget;
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
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
    );
  }
}
