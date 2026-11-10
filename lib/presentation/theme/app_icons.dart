import 'package:flutter/cupertino.dart';

/// Единственное место, где выбираются иконки. Сейчас CupertinoIcons; позже заменим на SF Symbols,
/// не трогая экраны.
abstract final class AppIcons {
  static const IconData settings = CupertinoIcons.settings;
  static const IconData add = CupertinoIcons.add;
  static const IconData back = CupertinoIcons.back;
  static const IconData rowUp = CupertinoIcons.chevron_up;
  static const IconData rowDown = CupertinoIcons.chevron_down;
  static const IconData rulerSettings = CupertinoIcons.slider_horizontal_3;
  static const IconData notes = CupertinoIcons.doc_text;
  static const IconData pages = CupertinoIcons.square_on_square;
  static const IconData selected = CupertinoIcons.checkmark;
  static const IconData craftBeading = CupertinoIcons.circle_grid_3x3_fill;
  static const IconData craftCrossStitch = CupertinoIcons.square_grid_2x2_fill;
}
