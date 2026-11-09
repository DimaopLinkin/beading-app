import 'package:flutter/cupertino.dart';

/// Единственное место, где выбираются иконки. Сейчас CupertinoIcons; позже заменим на SF Symbols,
/// не трогая экраны.
abstract final class AppIcons {
  static const IconData settings = CupertinoIcons.settings;
  static const IconData add = CupertinoIcons.add;
  static const IconData back = CupertinoIcons.back;
}
