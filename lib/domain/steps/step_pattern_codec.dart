import 'dart:convert';

import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/palette/catalog_ref.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/domain/palette/rgb.dart';
import 'package:beading/domain/steps/repeat.dart';
import 'package:beading/domain/steps/step_pattern.dart';

/// Документ инструкции (секции, шаги, палитра) в JSON, версия 1 (ADR-0008).
///
/// Картинки в документ не входят: шаги ссылаются на `imageIds`, файлы лежат в таблице `step_images`.
/// Ссылка на отсутствующую картинку при чтении — не ошибка.
abstract final class StepPatternCodec {
  /// Текущая версия документа; пишется в колонку `body_version` и в поле `v`.
  static const int version = 1;

  static String encode(StepPattern pattern) => jsonEncode(<String, Object?>{
    'v': version,
    'palette': <Object?>[
      for (final PatternColor c in pattern.palette)
        <String, Object?>{
          'rgb': (c.rgb.r << 16) | (c.rgb.g << 8) | c.rgb.b,
          'name': c.name,
          'components': <Object?>[
            for (final CatalogRef r in c.components) <String, String>{'brand': r.brand, 'code': r.code},
          ],
          'finish': c.finish,
          'symbol': c.symbol,
        },
    ],
    'sections': <Object?>[
      for (final StepSection s in pattern.sections)
        <String, Object?>{
          'id': s.id,
          'title': s.title,
          'repeat': _encodeRepeat(s.repeat),
          'steps': <Object?>[
            for (final InstructionStep st in s.steps)
              <String, Object?>{
                'id': st.id,
                'text': st.text,
                'images': st.imageIds,
                'beads': <Object?>[
                  for (final StepBead b in st.beads) <String, int>{'color': b.colorIndex, 'count': b.count},
                ],
                'repeat': _encodeRepeat(st.repeat),
              },
          ],
        },
    ],
  });

  /// Разбирает документ. Версия выше [version] или битый документ — [ValidationFailure].
  static Result<StepPattern> decode(
    String body, {
    required String id,
    required String projectId,
    List<StepImage> images = const <StepImage>[],
    String? templateId,
  }) {
    try {
      final Object? raw = jsonDecode(body);
      final Map<String, Object?> doc = _map(raw, 'документ');
      final int v = _int(doc['v'], 'версия');
      if (v < 1 || v > version) {
        return Err<StepPattern>(ValidationFailure('Версия документа инструкции $v не поддерживается'));
      }
      final List<PatternColor> palette = <PatternColor>[
        for (final Object? c in _list(doc['palette'], 'палитра')) _color(_map(c, 'цвет')),
      ];
      final Set<String> ids = <String>{};
      final List<StepSection> sections = <StepSection>[];
      for (final Object? rawSection in _list(doc['sections'], 'секции')) {
        final Map<String, Object?> s = _map(rawSection, 'секция');
        final List<InstructionStep> steps = <InstructionStep>[];
        for (final Object? rawStep in _list(s['steps'], 'шаги')) {
          final Map<String, Object?> st = _map(rawStep, 'шаг');
          final List<StepBead> beads = <StepBead>[
            for (final Object? rb in _list(st['beads'], 'бусины'))
              _bead(_map(rb, 'бусина'), palette.length),
          ];
          steps.add(
            InstructionStep(
              id: _unique(ids, _string(st['id'], 'id шага')),
              text: _string(st['text'], 'текст'),
              imageIds: <String>[for (final Object? i in _list(st['images'], 'картинки')) _string(i, 'id картинки')],
              beads: beads,
              repeat: _repeat(st['repeat']),
            ),
          );
        }
        sections.add(
          StepSection(
            id: _unique(ids, _string(s['id'], 'id секции')),
            title: _string(s['title'], 'название секции'),
            repeat: _repeat(s['repeat']),
            steps: steps,
          ),
        );
      }
      return Success<StepPattern>(
        StepPattern(
          id: id,
          projectId: projectId,
          palette: palette,
          sections: sections,
          images: images,
          templateId: templateId,
        ),
      );
    } on _BadDocument catch (e) {
      return Err<StepPattern>(ValidationFailure('Документ инструкции записан неверно: ${e.message}'));
    } on FormatException {
      return const Err<StepPattern>(ValidationFailure('Документ инструкции не разобрать'));
    }
  }

  /// `0` — «до нужной длины», иначе число проходов.
  static int _encodeRepeat(Repeat r) => r.count ?? 0;

  static Repeat _repeat(Object? value) {
    final int n = _int(value, 'повтор');
    if (n == 0) {
      return const Repeat.untilDone();
    }
    if (n < 0) {
      throw const _BadDocument('повтор меньше нуля');
    }
    return Repeat.times(n);
  }

  static StepBead _bead(Map<String, Object?> b, int paletteSize) {
    final int color = _int(b['color'], 'цвет бусины');
    final int count = _int(b['count'], 'число бусин');
    if (color < 0 || color >= paletteSize || count < 1) {
      throw const _BadDocument('бусина вне палитры');
    }
    return StepBead(colorIndex: color, count: count);
  }

  static PatternColor _color(Map<String, Object?> c) {
    final int rgb = _int(c['rgb'], 'цвет');
    if (rgb < 0 || rgb > 0xFFFFFF) {
      throw const _BadDocument('цвет вне диапазона');
    }
    final List<CatalogRef> refs = <CatalogRef>[
      for (final Object? r in _list(c['components'], 'состав цвета'))
        CatalogRef(
          brand: _string(_map(r, 'позиция')['brand'], 'бренд'),
          code: _string(_map(r, 'позиция')['code'], 'код'),
        ),
    ];
    if (refs.isEmpty || refs.length > PatternColor.maxComponents) {
      throw const _BadDocument('состав цвета');
    }
    return PatternColor(
      rgb: Rgb((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF),
      name: _string(c['name'], 'название цвета'),
      components: refs,
      finish: _optString(c['finish']),
      symbol: _optString(c['symbol']),
    );
  }

  static String _unique(Set<String> seen, String id) {
    if (id.isEmpty || !seen.add(id)) {
      throw const _BadDocument('id шага или секции пуст или повторяется');
    }
    return id;
  }

  static Map<String, Object?> _map(Object? v, String what) =>
      v is Map<String, Object?> ? v : throw _BadDocument('$what не объект');

  static List<Object?> _list(Object? v, String what) =>
      v is List<Object?> ? v : throw _BadDocument('$what не список');

  static int _int(Object? v, String what) => v is int ? v : throw _BadDocument('$what не число');

  static String _string(Object? v, String what) => v is String ? v : throw _BadDocument('$what не строка');

  static String? _optString(Object? v) => v == null ? null : _string(v, 'строка');
}

final class _BadDocument implements Exception {
  const _BadDocument(this.message);

  final String message;
}
