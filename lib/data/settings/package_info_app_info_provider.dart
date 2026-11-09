import 'package:beading/domain/settings/app_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Версия из Info.plist через `package_info_plus`.
class PackageInfoAppInfoProvider implements AppInfoProvider {
  const PackageInfoAppInfoProvider();

  @override
  Future<AppInfo> load() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return AppInfo(version: info.version, build: info.buildNumber);
  }
}
