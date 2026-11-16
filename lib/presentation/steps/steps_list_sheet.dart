import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/steps/steps_work_cubit.dart';
import 'package:beading/presentation/steps/steps_work_state.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Список шагов: группы по секциям, пройденные с галочкой, текущий выделен кольцом; касание строки переходит к шагу.
Future<void> showStepsListSheet(BuildContext context, StepsWorkCubit cubit) => showCupertinoSheet<void>(
  context: context,
  builder: (sheetContext) => BlocProvider<StepsWorkCubit>.value(value: cubit, child: const _StepsListPage()),
);

class _StepsListPage extends StatelessWidget {
  const _StepsListPage();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.stepsList),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l10n.stepsClose),
        ),
      ),
      child: BlocBuilder<StepsWorkCubit, StepsWorkState>(
        builder: (context, state) {
          if (!state.isReady) {
            return const SizedBox.shrink();
          }
          final StepPattern pattern = state.pattern!;
          int number = 0;
          return ListView(
            children: <Widget>[
              for (final (int index, StepSection section) in pattern.sections.indexed)
                if (section.steps.isNotEmpty)
                  _SectionGroup(
                    section: section,
                    sectionIndex: index,
                    firstNumber: (number += section.steps.length) - section.steps.length + 1,
                    state: state,
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  const _SectionGroup({
    required this.section,
    required this.sectionIndex,
    required this.firstNumber,
    required this.state,
  });

  final StepSection section;
  final int sectionIndex;
  final int firstNumber;
  final StepsWorkState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final List<StepSection> sections = state.pattern!.sections;
    final int currentIndex = sections.indexWhere((s) => s.id == state.progress!.sectionId);
    final int curStepIndex = currentIndex < 0
        ? -1
        : sections[currentIndex].steps.indexWhere((s) => s.id == state.progress!.stepId);
    final bool before = state.finished || sectionIndex < currentIndex;
    final bool isCurrentSection = !state.finished && sectionIndex == currentIndex;
    final int done = before
        ? section.steps.length
        : isCurrentSection
        ? curStepIndex
        : 0;
    final String repeat = section.repeat.isUntilDone
        ? l10n.stepsRepeatUntilDone
        : section.repeat.passes > 1
        ? l10n.stepsRepeatTimes(section.repeat.passes)
        : '';
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l),
            child: Text(
              <String>[
                if (section.title.isNotEmpty) section.title,
                if (repeat.isNotEmpty) repeat,
                l10n.stepsSectionProgress(done, section.steps.length),
              ].join(' · '),
              style: tokens.typography.caption.copyWith(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
            ),
          ),
          for (final (int i, InstructionStep step) in section.steps.indexed)
            _StepRow(
              number: firstNumber + i,
              step: step,
              done: i < done,
              current: isCurrentSection && i == curStepIndex && !state.finished,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.step, required this.done, required this.current});

  final int number;
  final InstructionStep step;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final StepsWorkCubit cubit = context.read<StepsWorkCubit>();
    final String title = step.text.isEmpty ? l10n.stepsNoText : step.text;
    return Semantics(
      button: true,
      selected: current,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          cubit.jumpTo(step.id);
          Navigator.of(context).maybePop();
        },
        child: ColoredBox(
          color: current ? tokens.colors.accentFill.resolveFrom(context) : const Color(0x00000000),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tokens.minTapTarget),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l, vertical: tokens.spacing.s),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 28,
                    child: done
                        ? Icon(CupertinoIcons.checkmark_alt, size: 20, color: tokens.accent.resolveFrom(context))
                        : current
                        ? Icon(
                            CupertinoIcons.largecircle_fill_circle,
                            size: 20,
                            color: tokens.accent.resolveFrom(context),
                          )
                        : null,
                  ),
                  Text(
                    '$number',
                    style: tokens.typography.callout.copyWith(
                      color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.s),
                  Expanded(
                    child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: tokens.typography.body),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
