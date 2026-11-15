import 'package:beading/domain/steps/repeat.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/steps_progress.dart';
import 'package:flutter_test/flutter_test.dart';

InstructionStep step(String id, [Repeat repeat = Repeat.once]) => InstructionStep(id: id, repeat: repeat);

StepPattern pattern(List<StepSection> sections) => StepPattern(id: 'p', projectId: 'pr', sections: sections);

StepsProgress at(String section, int sPass, String step, int stPass) =>
    StepsProgress(sectionId: section, sectionPass: sPass, stepId: step, stepPass: stPass);

void main() {
  group('start', () {
    test('первый шаг первой непустой секции', () {
      final StepPattern p = pattern(<StepSection>[
        const StepSection(id: 'a', steps: <InstructionStep>[]),
        StepSection(id: 'b', steps: <InstructionStep>[step('s1')]),
      ]);
      expect(StepsProgress.start(p), at('b', 1, 's1', 1));
    });

    test('без шагов инструкция пройдена', () {
      expect(StepsProgress.start(pattern(<StepSection>[])).finished, isTrue);
    });
  });

  group('next', () {
    final StepPattern p = pattern(<StepSection>[
      StepSection(
        id: 'a',
        repeat: const Repeat.times(2),
        steps: <InstructionStep>[step('s1', const Repeat.times(2)), step('s2')],
      ),
      StepSection(id: 'b', steps: <InstructionStep>[step('s3')]),
    ]);

    test('повтор шага, шаг, повтор секции, следующая секция, конец', () {
      StepsProgress cur = StepsProgress.start(p);
      final List<StepsProgress> trail = <StepsProgress>[cur];
      for (int i = 0; i < 6; i++) {
        cur = cur.next(p);
        trail.add(cur);
      }
      expect(trail.take(6).toList(), <StepsProgress>[
        at('a', 1, 's1', 1),
        at('a', 1, 's1', 2),
        at('a', 1, 's2', 1),
        at('a', 2, 's1', 1),
        at('a', 2, 's1', 2),
        at('a', 2, 's2', 1),
      ]);
      expect(trail[6], at('b', 1, 's3', 1));
      expect(trail[6].next(p).finished, isTrue);
    });

    test('на пройденной инструкции остаётся пройденной', () {
      final StepsProgress done = at('b', 1, 's3', 1).next(p);
      expect(done.next(p), done);
    });

    test('шаг «до нужной длины» растёт без предела, «Достаточно» идёт дальше', () {
      final StepPattern u = pattern(<StepSection>[
        StepSection(id: 'a', steps: <InstructionStep>[step('s1', const Repeat.untilDone()), step('s2')]),
      ]);
      StepsProgress cur = StepsProgress.start(u);
      for (int i = 0; i < 20; i++) {
        cur = cur.next(u);
      }
      expect(cur, at('a', 1, 's1', 21));
      expect(cur.skipRepeat(u), at('a', 1, 's2', 1));
    });

    test('секция «до нужной длины»: проход растёт, «Достаточно» выходит из секции', () {
      final StepPattern u = pattern(<StepSection>[
        StepSection(id: 'a', repeat: const Repeat.untilDone(), steps: <InstructionStep>[step('s1')]),
        StepSection(id: 'b', steps: <InstructionStep>[step('s2')]),
      ]);
      final StepsProgress second = at('a', 1, 's1', 1).next(u);
      expect(second, at('a', 2, 's1', 1));
      expect(second.skipRepeat(u), at('b', 1, 's2', 1));
    });

    test('«Достаточно» на шаге с числом повторов — обычный следующий', () {
      final StepPattern p2 = pattern(<StepSection>[
        StepSection(id: 'a', steps: <InstructionStep>[step('s1', const Repeat.times(3)), step('s2')]),
      ]);
      expect(at('a', 1, 's1', 1).skipRepeat(p2), at('a', 1, 's1', 2));
    });
  });

  group('previous', () {
    final StepPattern p = pattern(<StepSection>[
      StepSection(
        id: 'a',
        repeat: const Repeat.times(2),
        steps: <InstructionStep>[step('s1', const Repeat.times(2)), step('s2')],
      ),
      StepSection(id: 'b', steps: <InstructionStep>[step('s3')]),
    ]);

    test('через границу секции и повтора', () {
      expect(at('b', 1, 's3', 1).previous(p), at('a', 2, 's2', 1));
      expect(at('a', 2, 's1', 1).previous(p), at('a', 1, 's2', 1));
      expect(at('a', 1, 's2', 1).previous(p), at('a', 1, 's1', 2));
      expect(at('a', 1, 's1', 2).previous(p), at('a', 1, 's1', 1));
    });

    test('в самом начале остаётся на месте', () {
      expect(at('a', 1, 's1', 1).previous(p), at('a', 1, 's1', 1));
    });

    test('с пройденной инструкции возвращает на последний шаг', () {
      final StepsProgress done = at('b', 1, 's3', 1).next(p);
      expect(done.finished, isTrue);
      expect(done.previous(p), at('b', 1, 's3', 1));
    });
  });

  group('jumpTo', () {
    final StepPattern p = pattern(<StepSection>[
      StepSection(id: 'a', steps: <InstructionStep>[step('s1'), step('s2')]),
      StepSection(id: 'b', steps: <InstructionStep>[step('s3')]),
    ]);

    test('на начало шага в другой секции', () {
      expect(at('a', 1, 's1', 1).jumpTo(p, 's3'), at('b', 1, 's3', 1));
    });

    test('неизвестный шаг ничего не меняет', () {
      final StepsProgress cur = at('a', 1, 's2', 1);
      expect(cur.jumpTo(p, 'нет'), cur);
    });
  });

  group('fraction', () {
    final StepPattern p = pattern(<StepSection>[
      StepSection(
        id: 'a',
        repeat: const Repeat.times(2),
        steps: <InstructionStep>[step('s1', const Repeat.times(2)), step('s2')],
      ),
      StepSection(id: 'b', steps: <InstructionStep>[step('s3')]),
    ]);

    test('всего 2*(2+1)+1 = 7 единиц', () {
      expect(at('a', 1, 's1', 1).fraction(p), 0);
      expect(at('a', 1, 's2', 1).fraction(p), closeTo(2 / 7, 1e-9));
      expect(at('a', 2, 's1', 1).fraction(p), closeTo(3 / 7, 1e-9));
      expect(at('b', 1, 's3', 1).fraction(p), closeTo(6 / 7, 1e-9));
    });

    test('пройденная инструкция — 1', () {
      expect(at('b', 1, 's3', 1).next(p).fraction(p), 1);
    });

    test('«до нужной длины» не раздувает долю', () {
      final StepPattern u = pattern(<StepSection>[
        StepSection(id: 'a', steps: <InstructionStep>[step('s1', const Repeat.untilDone()), step('s2')]),
      ]);
      expect(at('a', 1, 's1', 50).fraction(u), 0);
      expect(at('a', 1, 's2', 1).fraction(u), 0.5);
    });
  });

  group('reconcile', () {
    final StepPattern before = pattern(<StepSection>[
      StepSection(id: 'a', steps: <InstructionStep>[step('s1'), step('s2'), step('s3')]),
    ]);

    test('шаг под курсором удалён: ближайший следующий', () {
      final StepPattern after = pattern(<StepSection>[
        StepSection(id: 'a', steps: <InstructionStep>[step('s1'), step('s3')]),
      ]);
      expect(at('a', 1, 's2', 1).reconcile(before: before, after: after), at('a', 1, 's3', 1));
    });

    test('удалён последний шаг: идём на последний оставшийся', () {
      final StepPattern after = pattern(<StepSection>[
        StepSection(id: 'a', steps: <InstructionStep>[step('s1'), step('s2')]),
      ]);
      expect(at('a', 1, 's3', 1).reconcile(before: before, after: after), at('a', 1, 's2', 1));
    });

    test('перестановка шагов не меняет «где я»', () {
      final StepPattern after = pattern(<StepSection>[
        StepSection(id: 'a', steps: <InstructionStep>[step('s3'), step('s1'), step('s2')]),
      ]);
      expect(at('a', 1, 's2', 1).reconcile(before: before, after: after), at('a', 1, 's2', 1));
    });

    test('шаг переехал в другую секцию: начало шага там', () {
      final StepPattern after = pattern(<StepSection>[
        StepSection(id: 'a', steps: <InstructionStep>[step('s1'), step('s3')]),
        StepSection(id: 'b', steps: <InstructionStep>[step('s2')]),
      ]);
      expect(at('a', 1, 's2', 1).reconcile(before: before, after: after), at('b', 1, 's2', 1));
    });

    test('все шаги удалены: пройдено', () {
      final StepPattern after = pattern(<StepSection>[const StepSection(id: 'a', steps: <InstructionStep>[])]);
      expect(at('a', 1, 's2', 1).reconcile(before: before, after: after).finished, isTrue);
    });
  });

  group('устаревший курсор и смена повторов', () {
    final StepPattern p = pattern(<StepSection>[
      StepSection(id: 'a', steps: <InstructionStep>[step('s1'), step('s2')]),
    ]);

    test('fraction при курсоре на несуществующий шаг или секцию — 0, а не «готово»', () {
      expect(at('нет', 1, 's1', 1).fraction(p), 0);
      expect(at('a', 1, 'нет', 1).fraction(p), 0);
    });

    test('reconcile ограничивает проходы новым числом повторов', () {
      final StepPattern before = pattern(<StepSection>[
        StepSection(
          id: 'a',
          repeat: const Repeat.times(10),
          steps: <InstructionStep>[step('s1', const Repeat.times(10))],
        ),
      ]);
      final StepPattern after = pattern(<StepSection>[
        StepSection(
          id: 'a',
          repeat: const Repeat.times(3),
          steps: <InstructionStep>[step('s1', const Repeat.times(2))],
        ),
      ]);
      expect(at('a', 8, 's1', 9).reconcile(before: before, after: after), at('a', 3, 's1', 2));
    });
  });
}
