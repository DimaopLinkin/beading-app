import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:beading/domain/image_pattern/crop_fit.dart';
import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/presentation/common/crop/crop_presets_panel.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

/// Результат редактора: рамка в долях повёрнутого изображения и выбранные пропорции.
class CropEditorResult extends Equatable {
  const CropEditorResult({required this.crop, this.aspect});

  final CropRect crop;

  /// Физический аспект рамки (ширина / высота), если выбран чип; `null` — рамка свободная.
  final double? aspect;

  @override
  List<Object?> get props => <Object?>[crop, aspect];
}

/// Экран обрезки: картинка с рамкой, края которой тянутся пальцем. Возвращает [CropRect] или `null` при отмене.
///
/// Обёртка над [showCropEditorResult] без панели пропорций (импорт книги).
Future<CropRect?> showCropEditor(
  BuildContext context, {
  required Uint8List bytes,
  required int quarterTurns,
  required CropRect initial,
}) async => (await showCropEditorResult(context, bytes: bytes, quarterTurns: quarterTurns, initial: initial))?.crop;

/// То же, что [showCropEditor], но возвращает и выбранный аспект; с [presets] внизу появляется панель чипов пропорций.
///
/// [sizeLabel] и [targetAspect] (ширина / высота в долях физического размера) добавляют чип «как размер вышивки».
Future<CropEditorResult?> showCropEditorResult(
  BuildContext context, {
  required Uint8List bytes,
  required int quarterTurns,
  required CropRect initial,
  bool presets = false,
  String? sizeLabel,
  double? targetAspect,
}) => Navigator.of(context).push<CropEditorResult>(
  CupertinoPageRoute<CropEditorResult>(
    fullscreenDialog: true,
    builder: (_) => CropEditor(
      bytes: bytes,
      quarterTurns: quarterTurns,
      initial: initial,
      presets: presets,
      sizeLabel: sizeLabel,
      targetAspect: targetAspect,
    ),
  ),
);

/// Готовое соотношение сторон: [a] : [b] в записи «меньшая : большая», кроме 16:9; либо размер вышивки.
class _Option {
  const _Option(this.a, this.b) : sizeLabel = null, sizeAspect = null;

  const _Option.size(String this.sizeLabel, double this.sizeAspect) : a = 0, b = 0;

  final int a;
  final int b;
  final String? sizeLabel;
  final double? sizeAspect;

  bool get isSize => sizeLabel != null;

  bool get isSquare => !isSize && a == b;

  /// Аспект (ширина / высота) в нужной ориентации.
  double aspect({required bool landscape}) {
    if (isSize) return sizeAspect!;
    final int hi = math.max(a, b);
    final int lo = math.min(a, b);
    return landscape ? hi / lo : lo / hi;
  }

  /// Подпись в ленте: у невыбранного как в списке, у выбранного — текущая ориентация.
  String label({required bool selected, required double current}) {
    if (isSize) return sizeLabel!;
    if (!selected) return '$a:$b';
    final int hi = math.max(a, b);
    final int lo = math.min(a, b);
    return current >= 1 ? '$hi:$lo' : '$lo:$hi';
  }
}

class CropEditor extends StatefulWidget {
  const CropEditor({
    required this.bytes,
    required this.quarterTurns,
    required this.initial,
    this.presets = false,
    this.sizeLabel,
    this.targetAspect,
    super.key,
  });

  final Uint8List bytes;
  final int quarterTurns;
  final CropRect initial;

  /// Показать панель чипов пропорций (в импорте книги выключена).
  final bool presets;

  /// Подпись чипа «как размер вышивки», например `60 × 80 см`; чип есть, только если задан и [targetAspect].
  final String? sizeLabel;

  /// Ширина / высота вышивки в долях физического размера.
  final double? targetAspect;

  @override
  State<CropEditor> createState() => _CropEditorState();
}

class _CropEditorState extends State<CropEditor> {
  static const double _minSide = 0.05;

  /// Радиус захвата вокруг края рамки: зона касания 2 × 24 = 48 pt, не меньше 44 pt по HIG. Она выходит за пределы
  /// картинки, поэтому рамку, прижатую к краю, можно взять и снаружи.
  static const double _grab = 24;

  /// Поле вокруг картинки, в котором ещё ловятся касания и рисуются ручки.
  static const double _margin = 28;

  /// Ширина окна, с которой панель пропорций уходит под фото, а кнопки — вниз (Mac).
  static const double _wideWidth = 700;

  /// Одно деление колёсика мыши в долях масштаба: чем больше, тем медленнее.
  static const double _wheelSlowdown = 300;

  late CropRect _crop = widget.initial;
  late final Future<ui.Image> _image = _decode();
  double? _imageAspect;
  String? _horizontal;
  String? _vertical;

  /// Выбранный чип (индекс в [_options]) или `null` — свободная рамка.
  int? _selected;
  double _aspect = 1;

  // Состояние жеста.
  CropRect _dragBase = CropRect.full;
  Offset _downPosition = Offset.zero;
  double _lastScale = 1;

  List<_Option> get _options => <_Option>[
    const _Option(1, 1),
    const _Option(2, 3),
    const _Option(3, 4),
    const _Option(4, 5),
    const _Option(16, 9),
    if (widget.sizeLabel != null && widget.targetAspect != null) _Option.size(widget.sizeLabel!, widget.targetAspect!),
  ];

  @override
  void initState() {
    super.initState();
    // Декодирование начинается сразу: ленивое поле иначе стартовало бы только при закрытии.
    unawaited(_image);
  }

  Future<ui.Image> _decode() async {
    final ui.Codec codec = await ui.instantiateImageCodec(widget.bytes);
    final ui.Image image = (await codec.getNextFrame()).image;
    codec.dispose();
    if (mounted) {
      setState(() {
        _imageAspect = widget.quarterTurns.isOdd ? image.height / image.width : image.width / image.height;
      });
    }
    return image;
  }

  // Выбор пропорций.

  void _onChip(int index) {
    final double? imageAspect = _imageAspect;
    if (imageAspect == null) return;
    if (_selected == index) {
      _rotate();
      return;
    }
    final _Option option = _options[index];
    setState(() {
      _selected = index;
      _aspect = option.aspect(landscape: imageAspect >= 1);
      _crop = CropFit.fitAspect(_crop, imageAspect, _aspect);
    });
  }

  bool get _canRotate {
    final int? index = _selected;
    if (index == null) return false;
    final _Option option = _options[index];
    return !option.isSquare && !option.isSize;
  }

  void _rotate() {
    final double? imageAspect = _imageAspect;
    if (imageAspect == null || !_canRotate) return;
    setState(() {
      _aspect = CropFit.rotateAspect(_aspect);
      _crop = CropFit.fitAspect(_crop, imageAspect, _aspect);
    });
  }

  void _reset() {
    final double? imageAspect = _imageAspect;
    setState(() {
      _crop = _selected == null || imageAspect == null
          ? CropRect.full
          : CropFit.fitAspect(CropRect.full, imageAspect, _aspect);
    });
  }

  // Геометрия.

  /// Рамка выбранного чипа: максимальная нужного аспекта по центру области.
  Rect _lockedFrame(Size area) {
    final double width = math.max(1, area.width - 2 * _margin);
    final double height = math.max(1, area.height - 2 * _margin);
    final Size size = width / height > _aspect ? Size(height * _aspect, height) : Size(width, width / _aspect);
    return Rect.fromCenter(center: area.center(Offset.zero), width: size.width, height: size.height);
  }

  /// Какие края рамки [inner] берёт касание в [position]: угол даёт сразу два края.
  (String?, String?) _edgesAt(Offset position, Rect inner) {
    final double left = inner.left;
    final double right = inner.right;
    final double top = inner.top;
    final double bottom = inner.bottom;
    final bool withinX = position.dx >= left - _grab && position.dx <= right + _grab;
    final bool withinY = position.dy >= top - _grab && position.dy <= bottom + _grab;
    final double dLeft = (position.dx - left).abs();
    final double dRight = (position.dx - right).abs();
    final double dTop = (position.dy - top).abs();
    final double dBottom = (position.dy - bottom).abs();
    final bool leftCloser = dLeft == dRight ? position.dx < (left + right) / 2 : dLeft < dRight;
    final bool topCloser = dTop == dBottom ? position.dy < (top + bottom) / 2 : dTop < dBottom;
    final double nearX = leftCloser ? dLeft : dRight;
    final double nearY = topCloser ? dTop : dBottom;
    return (
      withinY && nearX <= _grab ? (leftCloser ? 'left' : 'right') : null,
      withinX && nearY <= _grab ? (topCloser ? 'top' : 'bottom') : null,
    );
  }

  /// Касание пришло: запоминаем рамку и точку, определяем края (свободный режим) или выключаем чип (край рамки).
  void _onPointerDown(Offset position, Size area, Size size) {
    _horizontal = null;
    _vertical = null;
    _dragBase = _crop;
    _downPosition = position;
    if (_selected != null) {
      final (String? h, String? v) = _edgesAt(position, _lockedFrame(area));
      if (h != null || v != null) {
        // Касание края рамки возвращает свободную рамку с ручками; рамка остаётся как была в долях.
        setState(() => _selected = null);
      }
      return;
    }
    final Offset origin = _origin(area, size);
    final (String? h, String? v) = _edgesAt(
      position - origin,
      Rect.fromLTRB(
        _crop.left * size.width,
        _crop.top * size.height,
        _crop.right * size.width,
        _crop.bottom * size.height,
      ),
    );
    _horizontal = h;
    _vertical = v;
  }

  /// Свободный режим: край следует за пальцем. Считаем от рамки в момент касания, поэтому порог начала жеста не
  /// теряется и палец остаётся на крае.
  void _dragEdges(Offset total, Size size) {
    final String? horizontal = _horizontal;
    final String? vertical = _vertical;
    if (horizontal == null && vertical == null) {
      return;
    }
    final double dx = total.dx / size.width;
    final double dy = total.dy / size.height;
    final CropRect base = _dragBase;
    setState(() {
      double left = base.left;
      double right = base.right;
      double top = base.top;
      double bottom = base.bottom;
      if (horizontal == 'left') {
        left = (left + dx).clamp(0, right - _minSide);
      } else if (horizontal == 'right') {
        right = (right + dx).clamp(left + _minSide, 1);
      }
      if (vertical == 'top') {
        top = (top + dy).clamp(0, bottom - _minSide);
      } else if (vertical == 'bottom') {
        bottom = (bottom + dy).clamp(top + _minSide, 1);
      }
      _crop = CropRect(left: left, top: top, right: right, bottom: bottom);
    });
  }

  /// Режим с чипом: палец двигает фото под рамкой, щипок масштабирует. [photo] — размер фото на экране.
  void _moveLocked(ScaleUpdateDetails details, Size photo) {
    final double factor = details.scale > 0 ? details.scale / _lastScale : 1;
    if (details.scale > 0) _lastScale = details.scale;
    final Offset delta = details.focalPointDelta;
    setState(() {
      CropRect crop = _crop;
      if (factor != 1) crop = CropFit.zoomLocked(crop, factor);
      // Фото едет за пальцем, значит рамка относительно фото едет в обратную сторону.
      _crop = CropFit.panLocked(crop, -delta.dx / photo.width, -delta.dy / photo.height);
    });
  }

  void _wheel(PointerSignalEvent event) {
    if (_selected == null || event is! PointerScrollEvent) return;
    // Прокрутка вверх (отрицательная дельта) приближает.
    setState(() => _crop = CropFit.zoomLocked(_crop, math.exp(-event.scrollDelta.dy / _wheelSlowdown)));
  }

  @override
  void dispose() {
    unawaited(_image.then((image) => image.dispose()));
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(CropEditorResult(crop: _crop, aspect: _selected == null ? null : _aspect));

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool panel = widget.presets;
    final bool wide = panel && MediaQuery.sizeOf(context).width >= _wideWidth;
    final bool locked = _selected != null;
    final Widget cancel = CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => Navigator.of(context).pop(),
      child: Text(l10n.importBookCancel),
    );
    final Widget done = CupertinoButton(padding: EdgeInsets.zero, onPressed: _done, child: Text(l10n.importCropDone));
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.importCropTitle),
        automaticallyImplyLeading: !wide,
        leading: wide ? null : cancel,
        trailing: wide ? null : done,
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            if (wide)
              SizedBox(
                height: 28,
                child: locked
                    ? Center(
                        child: Text(
                          l10n.cropHintDesktop,
                          style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                          ),
                        ),
                      )
                    : null,
              ),
            Expanded(child: _canvas(context)),
            if (panel) _panel(context, l10n, wide: wide),
            if (wide)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: <Widget>[
                    CupertinoButton(onPressed: _reset, child: Text(l10n.importCropReset)),
                    const Spacer(),
                    cancel,
                    const SizedBox(width: 16),
                    CupertinoButton.filled(onPressed: _done, child: Text(l10n.importCropDone)),
                  ],
                ),
              )
            else if (!panel)
              CupertinoButton(onPressed: _reset, child: Text(l10n.importCropReset)),
          ],
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, AppLocalizations l10n, {required bool wide}) {
    final int? selected = _selected;
    final List<_Option> options = _options;
    final bool locked = selected != null;
    String? reason;
    if (selected != null) {
      if (options[selected].isSquare) reason = l10n.cropRotateSquareReason;
      if (options[selected].isSize) reason = l10n.cropRotateSizeReason;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: CropPresetsPanel(
        freeSelected: !locked,
        onFree: () => setState(() => _selected = null),
        chips: <CropChipData>[
          for (int i = 0; i < options.length; i++)
            CropChipData(
              label: options[i].label(selected: i == selected, current: _aspect),
              selected: i == selected,
              onTap: () => _onChip(i),
            ),
        ],
        onRotate: _canRotate ? _rotate : null,
        rotateReason: reason,
        hint: locked && !wide ? l10n.cropHintTouch : null,
        onReset: wide ? null : _reset,
      ),
    );
  }

  Widget _canvas(BuildContext context) {
    final double? imageAspect = _imageAspect;
    if (imageAspect == null) {
      return const Center(child: CupertinoActivityIndicator());
    }
    final Color accent = CupertinoColors.activeBlue.resolveFrom(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size area = constraints.biggest;
        final Size available = Size(math.max(1, area.width - 2 * _margin), math.max(1, area.height - 2 * _margin));
        final Size size = available.width / available.height > imageAspect
            ? Size(available.height * imageAspect, available.height)
            : Size(available.width, available.width / imageAspect);
        final bool locked = _selected != null;
        final Widget content;
        Size photo = size;
        if (locked) {
          final Rect frame = _lockedFrame(area);
          photo = Size(frame.width / _crop.width, frame.height / _crop.height);
          final Offset topLeft = Offset(frame.left - _crop.left * photo.width, frame.top - _crop.top * photo.height);
          content = Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Positioned(
                left: topLeft.dx,
                top: topLeft.dy,
                width: photo.width,
                height: photo.height,
                child: _photoImage(),
              ),
              CustomPaint(painter: _CropPainter(frame, accent, muted: true)),
              Positioned.fromRect(
                rect: frame,
                child: const IgnorePointer(child: SizedBox.expand(key: ValueKey<String>('crop-frame'))),
              ),
            ],
          );
        } else {
          content = Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: <Widget>[
                  _photoImage(),
                  CustomPaint(
                    painter: _CropPainter(
                      Rect.fromLTRB(
                        _crop.left * size.width,
                        _crop.top * size.height,
                        _crop.right * size.width,
                        _crop.bottom * size.height,
                      ),
                      accent,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        // Жест ловится на всей области, а не только на картинке: рамку у края берут и снаружи. Касание читаем
        // отдельно от жеста: у onScale порог начала (slop) вынес бы точку старта за пределы зоны захвата.
        return Listener(
          onPointerDown: (e) => _onPointerDown(e.localPosition, area, size),
          onPointerSignal: _wheel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => _lastScale = 1,
            onScaleUpdate: (d) {
              if (_selected != null) {
                _moveLocked(d, photo);
              } else if (d.pointerCount == 1) {
                _dragEdges(d.localFocalPoint - _downPosition, size);
              }
            },
            child: ClipRect(child: content),
          ),
        );
      },
    );
  }

  Widget _photoImage() => RotatedBox(
    quarterTurns: widget.quarterTurns,
    child: Image.memory(widget.bytes, fit: BoxFit.fill, gaplessPlayback: true),
  );

  Offset _origin(Size area, Size image) => Offset((area.width - image.width) / 2, (area.height - image.height) / 2);
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.inner, this.accent, {this.muted = false});

  /// Рамка в координатах холста.
  final Rect inner;
  final Color accent;

  /// Режим с чипом: вместо ручек приглушённые уголки, не интерактивные.
  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(all), Path()..addRect(inner)),
      Paint()..color = const Color(0x99000000),
    );
    if (muted) {
      _paintCorners(canvas);
      return;
    }
    canvas.drawRect(
      inner,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Явные «хваталки»: уголки и середины сторон, они рисуются и за пределами картинки, если рамка у края.
    final Paint handle = Paint()..color = accent;
    final Paint rim = Paint()..color = const Color(0xFFFFFFFF);
    for (final Offset point in <Offset>[
      inner.topLeft,
      inner.topRight,
      inner.bottomLeft,
      inner.bottomRight,
      inner.topCenter,
      inner.bottomCenter,
      inner.centerLeft,
      inner.centerRight,
    ]) {
      canvas
        ..drawCircle(point, 8, rim)
        ..drawCircle(point, 6, handle);
    }
  }

  /// Тонкая рамка и угловые скобки приглушённого белого.
  void _paintCorners(Canvas canvas) {
    final Paint hairline = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Paint corner = Paint()
      ..color = const Color(0xB3FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawRect(inner, hairline);
    final double arm = math.min(20, math.min(inner.width, inner.height) / 3);
    for (final (Offset point, double sx, double sy) in <(Offset, double, double)>[
      (inner.topLeft, 1, 1),
      (inner.topRight, -1, 1),
      (inner.bottomLeft, 1, -1),
      (inner.bottomRight, -1, -1),
    ]) {
      canvas
        ..drawLine(point, point + Offset(sx * arm, 0), corner)
        ..drawLine(point, point + Offset(0, sy * arm), corner);
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      oldDelegate.inner != inner || oldDelegate.accent != accent || oldDelegate.muted != muted;
}
