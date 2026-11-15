import 'dart:convert';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/steps/repeat.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_codec.dart';
import 'package:flutter_test/flutter_test.dart';

StepPattern sample() => StepPattern(
  id: 'p',
  projectId: 'pr',
  palette: <PatternColor>[
    PatternColor(
      rgb: const Rgb(10, 20, 30),
      name: 'Синий',
      components: const <CatalogRef>[CatalogRef(brand: 'Miyuki', code: 'DB0010')],
      finish: 'matte',
    ),
  ],
  sections: const <StepSection>[
    StepSection(
      id: 'a',
      title: 'Основа',
      repeat: Repeat.times(3),
      steps: <InstructionStep>[
        InstructionStep(
          id: 's1',
          text: 'Нанижи «3 × A»\nи закрепи',
          imageIds: <String>['i1', 'i2'],
          beads: <StepBead>[StepBead(colorIndex: 0, count: 3)],
          repeat: Repeat.untilDone(),
        ),
        InstructionStep(id: 's2'),
      ],
    ),
  ],
  templateId: 'raw',
);

void main() {
  test('кодирование и разбор возвращают ту же инструкцию', () {
    final StepPattern original = sample();
    final Result<StepPattern> back = StepPatternCodec.decode(
      StepPatternCodec.encode(original),
      id: 'p',
      projectId: 'pr',
      templateId: 'raw',
    );
    expect(back.valueOrNull, original);
  });

  test('пустая инструкция: одна пустая секция с одним пустым шагом', () {
    const StepPattern empty = StepPattern(
      id: 'p',
      projectId: 'pr',
      sections: <StepSection>[
        StepSection(
          id: 'a',
          steps: <InstructionStep>[InstructionStep(id: 's')],
        ),
      ],
    );
    expect(
      StepPatternCodec.decode(StepPatternCodec.encode(empty), id: 'p', projectId: 'pr').valueOrNull,
      empty,
    );
  });

  test('версия документа выше поддерживаемой — ValidationFailure', () {
    final Map<String, Object?> doc = jsonDecode(StepPatternCodec.encode(sample())) as Map<String, Object?>;
    doc['v'] = StepPatternCodec.version + 1;
    final Result<StepPattern> r = StepPatternCodec.decode(jsonEncode(doc), id: 'p', projectId: 'pr');
    expect(r.failureOrNull, isA<ValidationFailure>());
  });

  test('не JSON и не объект — ValidationFailure', () {
    expect(StepPatternCodec.decode('нет', id: 'p', projectId: 'pr').failureOrNull, isA<ValidationFailure>());
    expect(StepPatternCodec.decode('[]', id: 'p', projectId: 'pr').failureOrNull, isA<ValidationFailure>());
  });

  test('повторяющийся id шага — ValidationFailure', () {
    final Map<String, Object?> doc = jsonDecode(StepPatternCodec.encode(sample())) as Map<String, Object?>;
    final List<Object?> steps =
        ((doc['sections']! as List<Object?>).first! as Map<String, Object?>)['steps']! as List<Object?>;
    (steps[1]! as Map<String, Object?>)['id'] = 's1';
    expect(
      StepPatternCodec.decode(jsonEncode(doc), id: 'p', projectId: 'pr').failureOrNull,
      isA<ValidationFailure>(),
    );
  });

  test('бусина с цветом вне палитры — ValidationFailure', () {
    final String body = StepPatternCodec.encode(sample()).replaceFirst('"color":0', '"color":5');
    expect(StepPatternCodec.decode(body, id: 'p', projectId: 'pr').failureOrNull, isA<ValidationFailure>());
  });

  test('картинки не входят в документ, ссылка на отсутствующую картинку не ошибка', () {
    final Result<StepPattern> r = StepPatternCodec.decode(StepPatternCodec.encode(sample()), id: 'p', projectId: 'pr');
    expect(r.valueOrNull!.images, isEmpty);
    expect(r.valueOrNull!.referencedImageIds, <String>{'i1', 'i2'});
  });

  test('300 шагов и очень длинный текст', () {
    final StepPattern big = StepPattern(
      id: 'p',
      projectId: 'pr',
      sections: <StepSection>[
        StepSection(
          id: 'a',
          steps: <InstructionStep>[
            for (int i = 0; i < 300; i++) InstructionStep(id: 's$i', text: 'ж' * 5000),
          ],
        ),
      ],
    );
    expect(StepPatternCodec.decode(StepPatternCodec.encode(big), id: 'p', projectId: 'pr').valueOrNull, big);
  });
}
