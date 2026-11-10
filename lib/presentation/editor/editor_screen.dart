import 'dart:async';

import 'package:beading/domain/catalog/catalog_repository.dart';
import 'package:beading/domain/grid/cell_position.dart';
import 'package:beading/domain/grid/grid_geometry.dart';
import 'package:beading/domain/grid_pattern/grid_pattern.dart';
import 'package:beading/domain/palette/pattern_color.dart';
import 'package:beading/presentation/editor/color_sheet.dart';
import 'package:beading/presentation/editor/editor_canvas.dart';
import 'package:beading/presentation/editor/editor_cubit.dart';
import 'package:beading/presentation/editor/editor_state.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/app_glyph.dart';
import 'package:beading/presentation/widgets/glass/glass_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ширина окна, с которой палитра переезжает вбок (macOS и широкие окна).
const double editorWideBreakpoint = 720;

/// Экран редактора сеточной схемы: полотно, панель инструментов и палитра.
class EditorScreen extends StatelessWidget {
  const EditorScreen({required this.catalog, super.key});

  static const String routePath = '/editor/:projectId';

  static String locationFor(String projectId) => '/editor/$projectId';

  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return BlocBuilder<EditorCubit, EditorState>(
      builder: (context, state) {
        final EditorCubit cubit = context.read<EditorCubit>();
        return CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text(state.projectName),
            trailing: state.status == EditorStatus.ready
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _SaveBadge(state: state, onRetry: cubit.flush),
                      _NavButton(
                        buttonKey: 'undo',
                        label: l10n.editorUndo,
                        icon: AppIcons.undo,
                        onPressed: state.canUndo ? cubit.undo : null,
                      ),
                      _NavButton(
                        buttonKey: 'redo',
                        label: l10n.editorRedo,
                        icon: AppIcons.redo,
                        onPressed: state.canRedo ? cubit.redo : null,
                      ),
                    ],
                  )
                : null,
          ),
          child: SafeArea(
            child: switch (state.status) {
              EditorStatus.loading => const Center(child: CupertinoActivityIndicator()),
              EditorStatus.loadFailed => Center(child: Text(l10n.editorLoadFailed)),
              EditorStatus.ready => _Body(state: state, catalog: catalog),
            },
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.buttonKey, required this.label, required this.icon, required this.onPressed});

  final String buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    key: ValueKey<String>('editor-$buttonKey'),
    padding: EdgeInsets.zero,
    minimumSize: Size.square(context.tokens.minTapTarget),
    onPressed: onPressed,
    child: Semantics(label: label, child: Icon(icon, size: 22)),
  );
}

class _SaveBadge extends StatelessWidget {
  const _SaveBadge({required this.state, required this.onRetry});

  final EditorState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final (String text, Color color) = switch (state.save) {
      EditorSave.saved => (l10n.editorSaved, CupertinoColors.secondaryLabel.resolveFrom(context)),
      EditorSave.pending => (l10n.editorSaving, CupertinoColors.secondaryLabel.resolveFrom(context)),
      EditorSave.failed => (l10n.editorSaveFailed, CupertinoColors.systemRed.resolveFrom(context)),
    };
    final Widget label = Text(
      text,
      key: const ValueKey<String>('editor-save-status'),
      style: TextStyle(fontSize: 12, color: color),
    );
    if (state.save != EditorSave.failed) return label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(onRetry()),
      child: label,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.catalog});

  final EditorState state;
  final CatalogRepository catalog;

  @override
  Widget build(BuildContext context) {
    final EditorCubit cubit = context.read<EditorCubit>();
    final GridPattern pattern = state.pattern!;
    final bool wide = MediaQuery.sizeOf(context).width >= editorWideBreakpoint;
    final Widget canvas = Stack(
      children: <Widget>[
        Positioned.fill(
          child: EditorCanvas(
            pattern: pattern,
            tool: state.tool,
            showSymbols: state.showSymbols,
            selection: state.selection,
            onTap: cubit.tapCell,
            onStrokeStart: cubit.beginStroke,
            onStrokeCell: cubit.strokeTo,
            onStrokeEnd: cubit.endStroke,
            onSelect: cubit.selectRect,
          ),
        ),
        if (state.problem != null)
          Positioned(left: 12, right: 12, top: 8, child: _ProblemBanner(problem: state.problem!)),
      ],
    );
    final Widget palette = PaletteView(state: state, catalog: catalog, vertical: wide);
    final Widget tools = _ToolBar(state: state);
    if (wide) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(child: canvas),
                tools,
              ],
            ),
          ),
          SizedBox(width: 260, child: palette),
        ],
      );
    }
    return Column(
      children: <Widget>[
        Expanded(child: canvas),
        palette,
        tools,
      ],
    );
  }
}

class _ProblemBanner extends StatelessWidget {
  const _ProblemBanner({required this.problem});

  final EditorProblem problem;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String text = switch (problem) {
      EditorProblem.saveFailed => l10n.editorSaveFailed,
      EditorProblem.noColor => l10n.editorProblemNoColor,
      EditorProblem.paletteFull => l10n.editorProblemPaletteFull,
      EditorProblem.limitReached => l10n.editorProblemLimit,
      EditorProblem.lastRowOrColumn => l10n.editorProblemLast,
    };
    return GestureDetector(
      key: const ValueKey<String>('editor-problem'),
      onTap: context.read<EditorCubit>().dismissProblem,
      child: GlassBar(child: Text(text, textAlign: TextAlign.center)),
    );
  }
}

/// Палитра схемы: цвета-кружки, текущий с кольцом; «+» добавляет цвет. Повторное касание текущего — правка цвета.
class PaletteView extends StatelessWidget {
  const PaletteView({required this.state, required this.catalog, required this.vertical, super.key});

  final EditorState state;
  final CatalogRepository catalog;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final EditorCubit cubit = context.read<EditorCubit>();
    final GridPattern pattern = state.pattern!;
    final List<Widget> items = <Widget>[
      for (int i = 1; i <= pattern.palette.length; i++)
        _Swatch(
          value: i,
          color: pattern.palette.colorAt(i)!,
          active: state.activeColor == i,
          showSymbol: state.showSymbols,
          onTap: () {
            if (state.activeColor == i) {
              unawaited(_edit(context, i));
            } else {
              cubit.selectColor(i);
            }
          },
          onLongPress: () => unawaited(_edit(context, i)),
        ),
      _AddSwatch(label: l10n.editorAddColor, onTap: () => unawaited(_add(context))),
    ];
    if (vertical) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 10, runSpacing: 10, children: items),
      );
    }
    return SizedBox(
      height: 64,
      child: ListView(
        key: const ValueKey<String>('editor-palette'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: <Widget>[
          for (final Widget item in items) Padding(padding: const EdgeInsets.only(right: 10), child: item),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final EditorCubit cubit = context.read<EditorCubit>();
    final ColorSheetResult? result = await showColorSheet(context, catalog: catalog);
    if (result is ColorChosen) cubit.addColor(result.color);
  }

  Future<void> _edit(BuildContext context, int value) async {
    final EditorCubit cubit = context.read<EditorCubit>();
    final PatternColor initial = state.pattern!.palette.colorAt(value)!;
    final ColorSheetResult? result = await showColorSheet(context, catalog: catalog, initial: initial);
    switch (result) {
      case ColorChosen(:final PatternColor color):
        cubit.updateColor(value, color);
      case ColorDeleted():
        cubit.removeColor(value);
      case null:
        break;
    }
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.value,
    required this.color,
    required this.active,
    required this.showSymbol,
    required this.onTap,
    required this.onLongPress,
  });

  final int value;
  final PatternColor color;
  final bool active;
  final bool showSymbol;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color fill = Color.fromARGB(255, color.rgb.r, color.rgb.g, color.rgb.b);
    final bool light = fill.computeLuminance() > 0.5;
    return Semantics(
      button: true,
      selected: active,
      label: AppLocalizations.of(context).editorColorSwatch(color.name),
      child: GestureDetector(
        key: ValueKey<String>('swatch-$value'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? context.tokens.accent.resolveFrom(context)
                    : CupertinoColors.separator.resolveFrom(context),
                width: active ? 3 : 1,
              ),
            ),
            child: showSymbol && color.symbol != null
                ? Text(
                    color.symbol!,
                    style: TextStyle(
                      color: light ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _AddSwatch extends StatelessWidget {
  const _AddSwatch({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      key: const ValueKey<String>('palette-add'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: CupertinoColors.separator.resolveFrom(context), width: 1.5),
          ),
          child: const Icon(AppIcons.add, size: 22),
        ),
      ),
    ),
  );
}

/// Панель инструментов: рисование, зеркало, ряды/столбцы.
class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.state});

  final EditorState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final EditorCubit cubit = context.read<EditorCubit>();
    Widget tool(EditorTool t, String label, Widget icon) => _ToolButton(
      keyName: t.name,
      label: label,
      selected: state.tool == t,
      onTap: () => cubit.selectTool(t),
      child: icon,
    );
    return GlassBar(
      child: SingleChildScrollView(
        key: const ValueKey<String>('editor-toolbar'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            tool(EditorTool.brush, l10n.editorToolBrush, const Icon(AppIcons.brush)),
            tool(EditorTool.eraser, l10n.editorToolEraser, const AppGlyph(AppGlyphKind.eraser)),
            tool(EditorTool.fill, l10n.editorToolFill, const Icon(AppIcons.fill)),
            tool(EditorTool.pipette, l10n.editorToolPipette, const Icon(AppIcons.pipette)),
            tool(EditorTool.replaceColor, l10n.editorToolReplace, const Icon(AppIcons.replaceColor)),
            tool(EditorTool.selection, l10n.editorToolSelection, const AppGlyph(AppGlyphKind.selection)),
            _ToolButton(
              keyName: 'mirror',
              label: l10n.editorMirrorHorizontal,
              selected: false,
              onTap: () => unawaited(_mirrorMenu(context, state)),
              child: const AppGlyph(AppGlyphKind.mirror),
            ),
            _ToolButton(
              keyName: 'rows',
              label: l10n.editorRowsColumns,
              selected: false,
              onTap: () => unawaited(_rowsMenu(context, state)),
              child: const Icon(CupertinoIcons.table),
            ),
            _ToolButton(
              keyName: 'symbols',
              label: l10n.editorSymbols,
              selected: state.showSymbols,
              onTap: cubit.toggleSymbols,
              child: const Icon(CupertinoIcons.textformat),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mirrorMenu(BuildContext context, EditorState state) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final EditorCubit cubit = context.read<EditorCubit>();
    final bool shifted = state.pattern!.geometry is! RectangularGeometry;
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        message: shifted ? Text(l10n.editorMirrorNote) : null,
        actions: <Widget>[
          CupertinoActionSheetAction(
            key: const ValueKey<String>('mirror-h'),
            onPressed: () {
              Navigator.of(sheet).pop();
              cubit.mirrorHorizontal();
            },
            child: Text(l10n.editorMirrorHorizontal),
          ),
          CupertinoActionSheetAction(
            key: const ValueKey<String>('mirror-v'),
            onPressed: () {
              Navigator.of(sheet).pop();
              cubit.mirrorVertical();
            },
            child: Text(l10n.editorMirrorVertical),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheet).pop(),
          child: Text(l10n.newGridCancel),
        ),
      ),
    );
  }

  Future<void> _rowsMenu(BuildContext context, EditorState state) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final EditorCubit cubit = context.read<EditorCubit>();
    final CellPosition? focus = state.focus;
    Widget action(String key, String label, VoidCallback run, BuildContext sheet) => CupertinoActionSheetAction(
      key: ValueKey<String>(key),
      onPressed: () {
        Navigator.of(sheet).pop();
        run();
      },
      child: Text(label),
    );
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (sheet) => CupertinoActionSheet(
        message: focus == null ? Text(l10n.editorTouchFirst) : null,
        actions: focus == null
            ? const <Widget>[]
            : <Widget>[
                action('row-above', l10n.editorInsertRowAbove, () => cubit.insertRow(focus.row), sheet),
                action('row-below', l10n.editorInsertRowBelow, () => cubit.insertRow(focus.row + 1), sheet),
                action('row-delete', l10n.editorDeleteRow(focus.row + 1), () => cubit.deleteRow(focus.row), sheet),
                action('col-left', l10n.editorInsertColumnLeft, () => cubit.insertColumn(focus.column), sheet),
                action('col-right', l10n.editorInsertColumnRight, () => cubit.insertColumn(focus.column + 1), sheet),
                action(
                  'col-delete',
                  l10n.editorDeleteColumn(focus.column + 1),
                  () => cubit.deleteColumn(focus.column),
                  sheet,
                ),
              ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheet).pop(),
          child: Text(l10n.newGridCancel),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.keyName,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String keyName;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Color accent = context.tokens.accent.resolveFrom(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        key: ValueKey<String>('tool-$keyName'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 52,
          height: 52,
          child: IconTheme(
            data: IconThemeData(
              size: 24,
              color: selected ? accent : CupertinoColors.label.resolveFrom(context),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(context.tokens.radius.m),
                color: selected ? accent.withValues(alpha: 0.15) : null,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
