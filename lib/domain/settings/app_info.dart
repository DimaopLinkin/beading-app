import 'package:equatable/equatable.dart';

/// Версия приложения для экрана «О приложении».
final class AppInfo extends Equatable {
  const AppInfo({required this.version, required this.build});

  final String version;
  final String build;

  /// «0.1.0 (12)»; без номера сборки — только версия.
  String get display => build.isEmpty ? version : '$version ($build)';

  @override
  List<Object?> get props => <Object?>[version, build];
}

abstract interface class AppInfoProvider {
  Future<AppInfo> load();
}
