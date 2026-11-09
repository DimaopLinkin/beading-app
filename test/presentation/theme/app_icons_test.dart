import 'package:beading/presentation/theme/app_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('иконки берутся из CupertinoIcons', () {
    expect(AppIcons.settings, CupertinoIcons.settings);
    expect(AppIcons.add, CupertinoIcons.add);
    expect(AppIcons.back, CupertinoIcons.back);
  });
}
