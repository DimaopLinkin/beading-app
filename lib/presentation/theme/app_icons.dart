import 'package:flutter/cupertino.dart';

/// Единственное место, где выбираются иконки. Сейчас CupertinoIcons; позже заменим на SF Symbols,
/// не трогая экраны.
abstract final class AppIcons {
  static const IconData settings = CupertinoIcons.settings;
  static const IconData add = CupertinoIcons.add;
  static const IconData back = CupertinoIcons.chevron_back; // шеврон, не треугольник (замечание ревью 01b)
  static const IconData rowUp = CupertinoIcons.chevron_up;
  static const IconData rowDown = CupertinoIcons.chevron_down;
  static const IconData resize = CupertinoIcons.arrow_up_down;
  static const IconData resizeWide = CupertinoIcons.arrow_left_right;
  static const IconData zoneFrame = CupertinoIcons.crop;
  static const IconData minus = CupertinoIcons.minus;
  static const IconData warning = CupertinoIcons.exclamationmark_triangle;
  static const IconData forward = CupertinoIcons.chevron_forward;
  static const IconData rulerSettings = CupertinoIcons.slider_horizontal_3;
  static const IconData notes = CupertinoIcons.doc_text;
  static const IconData pages = CupertinoIcons.square_on_square;
  static const IconData share = CupertinoIcons.share;
  static const IconData catalog = CupertinoIcons.color_filter;
  static const IconData selected = CupertinoIcons.checkmark;
  static const IconData craftBeading = CupertinoIcons.circle_grid_3x3_fill;
  static const IconData craftCrossStitch = CupertinoIcons.square_grid_2x2_fill;

  static const IconData photo = CupertinoIcons.photo;
  static const IconData search = CupertinoIcons.search;

  // Инструменты редактора (01b, п. 6). Eraser, selection, mirror и режим «по бусине» нарисованы виджетом `AppGlyph`.
  static const IconData brush = CupertinoIcons.paintbrush;
  static const IconData fill = CupertinoIcons.drop;
  static const IconData pipette = CupertinoIcons.eyedropper;
  static const IconData replaceColor = CupertinoIcons.arrow_left_right;
  static const IconData undo = CupertinoIcons.arrow_uturn_left;
  static const IconData redo = CupertinoIcons.arrow_uturn_right;

  /// Имена SF Symbols для будущей нативной подмены (по таблице 01b). Проверены по названию, но не в приложении
  /// SF Symbols: `paintbucket.classic` может отсутствовать в старых версиях, запасной `drop.fill`.
  static const Map<String, String> sfSymbols = <String, String>{
    'brush': 'paintbrush.pointed',
    'eraser': 'eraser',
    'fill': 'paintbucket.classic',
    'pipette': 'eyedropper',
    'replaceColor': 'arrow.left.arrow.right',
    'selection': 'rectangle.dashed',
    'mirror': 'arrow.left.and.right.righttriangle.left.righttriangle.right',
    'undo': 'arrow.uturn.backward',
    'redo': 'arrow.uturn.forward',
    'rowUp': 'chevron.up',
    'rowDown': 'chevron.down',
    'forward': 'chevron.forward',
    'resize': 'arrow.up.arrow.down',
    'warning': 'exclamationmark.triangle',
    'search': 'magnifyingglass',
    'add': 'plus',
  };
}
