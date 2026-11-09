import 'package:beading/presentation/theme/app_theme.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// Образец токенов: цвета подсветки/притушения, стекло, радиусы и цифры счётчика.
class _TokenSwatch extends StatelessWidget {
  const _TokenSwatch();

  @override
  Widget build(BuildContext context) {
    final AppTokensData t = context.tokens;
    Widget box(Color color, double radius, String label) => Container(
      width: 120,
      height: 56,
      margin: EdgeInsets.all(t.spacing.s),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: CupertinoDynamicColor.resolve(t.glassSurface.border, context)),
      ),
      alignment: Alignment.center,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );

    return ColoredBox(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: Padding(
        padding: EdgeInsets.all(t.spacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Wrap(
              children: <Widget>[
                box(CupertinoDynamicColor.resolve(t.rowHighlight, context), t.radius.s, 'highlight'),
                box(CupertinoDynamicColor.resolve(t.rowDim, context), t.radius.m, 'dim'),
                box(CupertinoDynamicColor.resolve(t.glassSurface.tint, context), t.radius.l, 'glass'),
                box(CupertinoDynamicColor.resolve(t.glassBar.tint, context), t.radius.xl, 'bar'),
              ],
            ),
            Text('0123456789', style: t.counterTextStyle),
            Text('1111111111', style: t.counterTextStyle),
          ],
        ),
      ),
    );
  }
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    testWidgets('образец токенов, ${brightness.name}', (tester) async {
      await tester.binding.setSurfaceSize(const Size(560, 220));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        CupertinoApp(
          debugShowCheckedModeBanner: false,
          builder: AppTheme.builder,
          theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
          home: const SizedBox(width: 560, child: _TokenSwatch()),
        ),
      );

      await expectLater(find.byType(_TokenSwatch), matchesGoldenFile('goldens/token_swatch_${brightness.name}.png'));
    });
  }
}
