import 'package:beading/data/settings/package_info_app_info_provider.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  test('читает версию и номер сборки из пакета', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Бисер',
      packageName: 'app.beading',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );

    expect(await const PackageInfoAppInfoProvider().load(), const AppInfo(version: '1.2.3', build: '45'));
  });
}
