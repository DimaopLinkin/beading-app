import 'package:beading/domain/image_pattern/crop_rect.dart';
import 'package:beading/presentation/import_book/crop_editor.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_images.dart';

void main() {
  for (final CupertinoThemeData theme in <CupertinoThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('рамка тянется за пальцем и возвращается по «Готово» в теме ${theme.brightness}', (tester) async {
      final png = (await tester.runAsync(() => redBluePng(width: 40, height: 40)))!;
      CropRect? result;
      await tester.pumpWidget(
        CupertinoApp(
          theme: theme,
          builder: AppTheme.builder,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => CupertinoButton(
              onPressed: () async =>
                  result = await showCropEditor(context, bytes: png, quarterTurns: 0, initial: CropRect.full),
              child: const Text('открыть'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('открыть'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();

      final Finder image = find.byType(Image);
      expect(image, findsOneWidget);
      final Rect box = tester.getRect(image);
      // Берём левый край рамки и тянем на четверть ширины.
      await tester.dragFrom(box.centerLeft + const Offset(2, 0), Offset(box.width / 4, 0));
      await tester.pump();
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.left, closeTo(0.25, 0.05));
      expect(result!.right, 1);
    });
  }

  testWidgets('рамку у края берут снаружи картинки и за угол сразу двумя краями', (tester) async {
    final png = (await tester.runAsync(() => redBluePng(width: 40, height: 40)))!;
    CropRect? result;
    await tester.pumpWidget(
      CupertinoApp(
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async =>
                result = await showCropEditor(context, bytes: png, quarterTurns: 0, initial: CropRect.full),
            child: const Text('открыть'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final Rect box = tester.getRect(find.byType(Image));
    // Касание на 15 pt левее и выше картинки: это угол рамки, тянем его внутрь.
    await tester.dragFrom(box.topLeft - const Offset(15, 15), Offset(box.width / 4, box.height / 4));
    await tester.pump();
    await tester.tap(find.text('Готово'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.left, closeTo(0.25, 0.05));
    expect(result!.top, closeTo(0.25, 0.05));
    expect(result!.right, 1);
    expect(result!.bottom, 1);
  });

  testWidgets('отмена не возвращает рамку', (tester) async {
    final png = (await tester.runAsync(redBluePng))!;
    CropRect? result = CropRect.full;
    await tester.pumpWidget(
      CupertinoApp(
        builder: AppTheme.builder,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CupertinoButton(
            onPressed: () async =>
                result = await showCropEditor(context, bytes: png, quarterTurns: 1, initial: CropRect.full),
            child: const Text('открыть'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('открыть'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
