import 'package:beading/domain/settings/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('display склеивает версию и сборку', () {
    expect(const AppInfo(version: '0.1.0', build: '12').display, '0.1.0 (12)');
    expect(const AppInfo(version: '0.1.0', build: '').display, '0.1.0');
  });
}
