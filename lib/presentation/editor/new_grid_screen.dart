import 'package:beading/domain/editor/technique_geometry.dart';
import 'package:beading/domain/grid/bead_size.dart';
import 'package:beading/domain/projects/craft.dart';
import 'package:beading/presentation/editor/new_grid_cubit.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Лист создания схемы. Закрывается с id созданного проекта.
class NewGridScreen extends StatelessWidget {
  const NewGridScreen({super.key});

  static const String routePath = '/editor/new';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocConsumer<NewGridCubit, NewGridState>(
      listenWhen: (before, after) => before.projectId == null && after.projectId != null,
      listener: (context, state) => Navigator.of(context).maybePop(state.projectId),
      builder: (context, state) {
        final NewGridCubit cubit = context.read<NewGridCubit>();
        final double gap = context.tokens.spacing.m;
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(l10n.newGridTitle),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: state.creating ? null : () => Navigator.of(context).maybePop(),
              child: Text(l10n.newGridCancel),
            ),
            trailing: CupertinoButton(
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
                  key: const ValueKey<String>('new-grid-name'),
                  placeholder: l10n.newGridName,
                  onChanged: cubit.setName,
                ),
                SizedBox(height: gap),
                _Label(l10n.newGridTechnique),
                CupertinoSlidingSegmentedControl<Technique>(
                  groupValue: state.technique,
                  children: <Technique, Widget>{
                    for (final Technique t in editorBeadingTechniques)
                      t: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(t.label(l10n)),
                      ),
                  },
                  onValueChanged: (value) {
                    if (value != null) cubit.setTechnique(value);
                  },
                ),
                SizedBox(height: gap),
                _Stepper(
                  keyPrefix: 'width',
                  label: l10n.newGridWidth,
                  value: state.width,
                  onChanged: cubit.setWidth,
                ),
                SizedBox(height: gap),
                _Stepper(
                  keyPrefix: 'height',
                  label: l10n.newGridHeight,
                  value: state.height,
                  onChanged: cubit.setHeight,
                ),
                SizedBox(height: gap),
                _Label(l10n.newGridBead),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final BeadSize size in BeadSize.values)
                      _BeadChip(size: size, selected: size == state.bead, onTap: () => cubit.setBead(size)),
                  ],
                ),
                SizedBox(height: gap),
                Text(
                  state.validSize ? _cm(l10n, state) : l10n.newGridSizeInvalid,
                  key: const ValueKey<String>('new-grid-size'),
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

  String _cm(AppLocalizations l10n, NewGridState state) {
    String cm(double mm) => (mm / 10).toStringAsFixed(1).replaceAll('.', ',');
    return l10n.newGridSizeCm(cm(state.sizeMm.width), cm(state.sizeMm.height));
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
    ),
  );
}

class _BeadChip extends StatelessWidget {
  const _BeadChip({required this.size, required this.selected, required this.onTap});

  final BeadSize size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name = size.shape == BeadShape.delica ? 'Delica' : 'Рокайль';
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: ValueKey<String>('bead-${size.shape.name}-${size.sizeCode}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: context.tokens.minTapTarget),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected
                  ? context.tokens.colors.accentFill.resolveFrom(context)
                  : CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(context.tokens.radius.m),
              border: selected ? Border.all(color: context.tokens.colors.accent.resolveFrom(context), width: 2) : null,
            ),
            child: Text('$name ${size.sizeCode}'),
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.keyPrefix, required this.label, required this.value, required this.onChanged});

  final String keyPrefix;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label)),
        CupertinoButton(
          key: ValueKey<String>('$keyPrefix-minus'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: value > NewGridState.minSide ? () => onChanged(value - 1) : null,
          child: const Icon(CupertinoIcons.minus_circle),
        ),
        SizedBox(
          width: 64,
          child: CupertinoTextField(
            key: ValueKey<String>('$keyPrefix-field'),
            controller: TextEditingController.fromValue(
              TextEditingValue(
                text: '$value',
                selection: TextSelection.collapsed(offset: '$value'.length),
              ),
            ),
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            onChanged: (text) => onChanged(int.tryParse(text) ?? 0),
          ),
        ),
        CupertinoButton(
          key: ValueKey<String>('$keyPrefix-plus'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: value < NewGridState.maxSide ? () => onChanged(value + 1) : null,
          child: const Icon(CupertinoIcons.plus_circle),
        ),
      ],
    );
  }
}
