import 'dart:typed_data';

import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/presentation/common/crop/crop_editor.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_images.dart';

/// Результат редактора: рамка и выбранный аспект.
CropEditorResult? _result;

/// Физический аспект рамки: доля ширины × аспект картинки / доля высоты.
double _physical(CropRect c, double imageAspect) => c.width * imageAspect / c.height;

Future<void> _open(
  WidgetTester tester, {
  required Uint8List png,
  bool presets = true,
  String? sizeLabel,
  double? targetAspect,
  Size window = const Size(390, 844),
  CropRect initial = CropRect.full,
}) async {
  tester.view
    ..physicalSize = window
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _result = null;
  await tester.pumpWidget(
    CupertinoApp(
      builder: AppTheme.builder,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => CupertinoButton(
          onPressed: () async => _result = await showCropEditorResult(
            context,
            bytes: png,
            quarterTurns: 0,
            initial: initial,
            presets: presets,
            sizeLabel: sizeLabel,
            targetAspect: targetAspect,
          ),
          child: const Text('открыть'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('открыть'));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pumpAndSettle();
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<CropEditorResult> _done(WidgetTester tester) async {
  await tester.tap(find.text('Готово'));
  await tester.pumpAndSettle();
  return _result!;
}

Finder get _frame => find.byKey(const ValueKey<String>('crop-frame'));

Finder get _rotate => find.byIcon(AppIcons.rotateFrame);

void main() {
  late Uint8List landscape; // 40 × 20, аспект 2
  late Uint8List portrait; // 20 × 40, аспект 0,5

  Future<void> loadImages(WidgetTester tester) async {
    landscape = (await tester.runAsync(() => redBluePng(width: 40, height: 20)))!;
    portrait = (await tester.runAsync(() => redBluePng(width: 20, height: 40)))!;
  }

  group('без пресетов (импорт книги)', () {
    testWidgets('панели чипов нет, остаются «Сбросить» и «Готово», результат без аспекта', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape, presets: false);
      expect(find.text('Свободно'), findsNothing);
      expect(find.text('3:4'), findsNothing);
      expect(find.text('Сбросить'), findsOneWidget);
      final CropEditorResult r = await _done(tester);
      expect(r.crop, CropRect.full);
      expect(r.aspect, isNull);
    });
  });

  group('чипы', () {
    testWidgets('по умолчанию свободная рамка без аспекта', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape);
      expect(find.text('Свободно'), findsOneWidget);
      expect(find.text('1:1'), findsOneWidget);
      expect(find.text('2:3'), findsOneWidget);
      expect(find.text('3:4'), findsOneWidget);
      expect(find.text('4:5'), findsOneWidget);
      expect(find.text('16:9'), findsOneWidget);
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, isNull);
      expect(r.crop, CropRect.full);
    });

    testWidgets('3:4 на горизонтальном фото встаёт альбомной 4:3 с нужным аспектом', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape);
      await _tapChip(tester, '3:4');
      expect(find.text('4:3'), findsOneWidget);
      expect(find.text('Двигайте и масштабируйте фото'), findsOneWidget);
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, closeTo(4 / 3, 1e-9));
      expect(_physical(r.crop, 2), closeTo(4 / 3, 1e-6));
      expect(r.crop.left, closeTo(1 / 6, 1e-6));
      expect(r.crop.right, closeTo(5 / 6, 1e-6));
    });

    testWidgets('3:4 на вертикальном фото остаётся портретной', (tester) async {
      await loadImages(tester);
      await _open(tester, png: portrait);
      await _tapChip(tester, '3:4');
      expect(find.text('3:4'), findsOneWidget);
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, closeTo(0.75, 1e-9));
      expect(_physical(r.crop, 0.5), closeTo(0.75, 1e-6));
    });

    testWidgets('кнопка «Повернуть рамку» и повторное нажатие на чип переворачивают 3:4 и 4:3', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape);
      await _tapChip(tester, '3:4');
      expect(find.text('4:3'), findsOneWidget);
      await tester.tap(_rotate);
      await tester.pumpAndSettle();
      expect(find.text('3:4'), findsOneWidget);
      await tester.tap(find.text('3:4'));
      await tester.pumpAndSettle();
      expect(find.text('4:3'), findsOneWidget);
      await tester.tap(_rotate);
      await tester.pumpAndSettle();
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, closeTo(0.75, 1e-9));
      expect(_physical(r.crop, 2), closeTo(0.75, 1e-6));
    });

    testWidgets('16:9 в вертикальной ориентации подписан 9:16', (tester) async {
      await loadImages(tester);
      await _open(tester, png: portrait);
      await _tapChip(tester, '16:9');
      expect(find.text('9:16'), findsOneWidget);
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, closeTo(9 / 16, 1e-9));
    });

    testWidgets('квадрат не переворачивается, причина показана', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape);
      await _tapChip(tester, '1:1');
      expect(find.text('Квадрат не поворачивается'), findsOneWidget);
      await tester.tap(_rotate);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1:1'));
      await tester.pumpAndSettle();
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, 1);
      expect(_physical(r.crop, 2), closeTo(1, 1e-6));
    });

    testWidgets('чип размера вышивки даёт аспект из targetAspect', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape, sizeLabel: '60 × 80 см', targetAspect: 0.75);
      expect(find.text('60 × 80 см'), findsOneWidget);
      await _tapChip(tester, '60 × 80 см');
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, closeTo(0.75, 1e-9));
      expect(_physical(r.crop, 2), closeTo(0.75, 1e-6));
    });

    testWidgets('чипа размера нет без sizeLabel', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape);
      expect(find.textContaining('см'), findsNothing);
    });

    testWidgets('«Свободно» возвращает свободную рамку, рамка остаётся как была', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape);
      await _tapChip(tester, '2:3');
      await _tapChip(tester, 'Свободно');
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, isNull);
      expect(_physical(r.crop, 2), closeTo(3 / 2, 1e-6));
    });
  });

  group('рамка с чипом', () {
    testWidgets('рамка стоит по центру области, фото вокруг затемнено', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape);
      await _tapChip(tester, '1:1');
      final Rect frame = tester.getRect(_frame);
      final Rect photo = tester.getRect(find.byType(Image));
      expect(frame.width, closeTo(frame.height, 0.5));
      expect(photo.center.dx, closeTo(frame.center.dx, 1));
      // Фото 2:1 под квадратной рамкой выходит за неё по ширине.
      expect(photo.width, greaterThan(frame.width * 1.9));
    });

    testWidgets('одним пальцем двигается фото, рамка стоит', (tester) async {
      await loadImages(tester);
      await _open(tester, png: portrait);
      await _tapChip(tester, '3:4');
      final Rect frame = tester.getRect(_frame);
      final CropRect before = _peek(tester);
      // Тянем фото вверх: рамка уходит вниз по фото.
      await tester.dragFrom(frame.center, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(_frame), frame);
      final CropEditorResult r = await _done(tester);
      expect(r.crop.bottom, closeTo(1, 1e-9));
      expect(r.crop.top, greaterThan(before.top));
      expect(r.aspect, closeTo(0.75, 1e-9));
    });

    testWidgets('щипок приближает, рамка сохраняет аспект', (tester) async {
      await loadImages(tester);
      await _open(tester, png: portrait);
      await _tapChip(tester, '3:4');
      final Offset c = tester.getRect(_frame).center;
      final TestGesture a = await tester.startGesture(c - const Offset(40, 0));
      final TestGesture b = await tester.startGesture(c + const Offset(40, 0));
      await a.moveBy(const Offset(-30, 0));
      await b.moveBy(const Offset(30, 0));
      await a.moveBy(const Offset(-30, 0));
      await b.moveBy(const Offset(30, 0));
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      final CropEditorResult r = await _done(tester);
      expect(r.crop.width, lessThan(0.8));
      expect(_physical(r.crop, 0.5), closeTo(0.75, 1e-6));
    });

    testWidgets('отдалить за предел нельзя: полей не появляется', (tester) async {
      await loadImages(tester);
      await _open(tester, png: portrait);
      await _tapChip(tester, '3:4');
      final Offset c = tester.getRect(_frame).center;
      final TestGesture a = await tester.startGesture(c - const Offset(80, 0));
      final TestGesture b = await tester.startGesture(c + const Offset(80, 0));
      await a.moveBy(const Offset(60, 0));
      await b.moveBy(const Offset(-60, 0));
      await a.moveBy(const Offset(10, 0));
      await b.moveBy(const Offset(-10, 0));
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      final CropEditorResult r = await _done(tester);
      expect(r.crop.width, closeTo(1, 1e-9));
      expect(r.crop.left, 0);
      expect(r.crop.right, 1);
    });

    testWidgets('колесо мыши масштабирует фото', (tester) async {
      await loadImages(tester);
      await _open(tester, png: portrait, window: const Size(960, 700));
      await _tapChip(tester, '3:4');
      final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(tester.getRect(_frame).center));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -200)));
      await tester.pumpAndSettle();
      final CropEditorResult r = await _done(tester);
      expect(r.crop.width, lessThan(0.9));
      expect(_physical(r.crop, 0.5), closeTo(0.75, 1e-6));
    });

    testWidgets('касание края рамки выключает чип, рамка остаётся как была', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape);
      await _tapChip(tester, '1:1');
      final Rect frame = tester.getRect(_frame);
      await tester.tapAt(frame.centerLeft + const Offset(2, 0));
      await tester.pumpAndSettle();
      // Подпись выбранного чипа снова обычная, а рамка свободная: тянем левый край фото-рамки.
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, isNull);
      expect(_physical(r.crop, 2), closeTo(1, 1e-6));
    });

    testWidgets('после выключения чипа край снова тянется', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape);
      await _tapChip(tester, '1:1');
      await tester.tapAt(tester.getRect(_frame).centerLeft + const Offset(2, 0));
      await tester.pumpAndSettle();
      final Rect box = tester.getRect(find.byType(Image));
      // Свободная рамка квадрат 0,25…0,75 по ширине: берём её левый край.
      final double edgeX = box.left + box.width * 0.25;
      await tester.dragFrom(Offset(edgeX, box.center.dy), Offset(box.width / 10, 0));
      await tester.pumpAndSettle();
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, isNull);
      expect(r.crop.left, closeTo(0.35, 0.03));
    });

    testWidgets('«Сбросить» с чипом возвращает максимальную рамку того же аспекта', (tester) async {
      await loadImages(tester);
      await _open(tester, png: portrait);
      await _tapChip(tester, '3:4');
      await tester.dragFrom(tester.getRect(_frame).center, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сбросить'));
      await tester.pumpAndSettle();
      final CropEditorResult r = await _done(tester);
      expect(r.aspect, closeTo(0.75, 1e-9));
      expect(r.crop.width, closeTo(1, 1e-9));
      expect(r.crop.top, closeTo((1 - r.crop.height) / 2, 1e-9));
    });
  });

  group('Mac', () {
    testWidgets('внизу «Сбросить», «Отмена», «Готово», чипы под фото, подсказка про колесо', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape, window: const Size(960, 700));
      expect(find.text('Сбросить'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      expect(find.text('Готово'), findsOneWidget);
      final double chipsTop = tester.getRect(find.text('Свободно')).top;
      expect(chipsTop, greaterThan(tester.getRect(find.byType(Image)).bottom));
      await _tapChip(tester, '2:3');
      expect(find.text('Колесо мыши или щипок трекпада масштабирует фото'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(_result, isNull);
    });
  });

  group('свободная рамка (старое поведение)', () {
    testWidgets('края тянутся и с панелью чипов', (tester) async {
      await loadImages(tester);
      await _open(tester, png: landscape);
      final Rect box = tester.getRect(find.byType(Image));
      await tester.dragFrom(box.centerLeft + const Offset(2, 0), Offset(box.width / 4, 0));
      await tester.pumpAndSettle();
      final CropEditorResult r = await _done(tester);
      expect(r.crop.left, closeTo(0.25, 0.05));
      expect(r.aspect, isNull);
    });

    testWidgets('старая обёртка showCropEditor возвращает CropRect', (tester) async {
      await loadImages(tester);
      CropRect? crop;
      await tester.pumpWidget(
        CupertinoApp(
          builder: AppTheme.builder,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async =>
                  crop = await showCropEditor(context, bytes: landscape, quarterTurns: 0, initial: CropRect.full),
              child: const Text('открыть'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();
      expect(crop, CropRect.full);
    });
  });
}

/// Текущая рамка в долях фото по видимой геометрии: рамка и фото на экране.
CropRect _peek(WidgetTester tester) {
  final Rect frame = tester.getRect(_frame);
  final Rect photo = tester.getRect(find.byType(Image));
  return CropRect(
    left: (frame.left - photo.left) / photo.width,
    top: (frame.top - photo.top) / photo.height,
    right: (frame.right - photo.left) / photo.width,
    bottom: (frame.bottom - photo.top) / photo.height,
  );
}
