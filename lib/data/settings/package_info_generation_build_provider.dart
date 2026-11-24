import 'package:beading/domain/image_to_grid/generation_stamp.dart';
import 'package:beading/domain/image_to_grid/generator_version.dart';
import 'package:beading/domain/settings/app_info.dart';

/// Короткий git-хэш, который `scripts/kanitel.sh` кладёт в сборку (`--dart-define=GIT_SHA`); без скрипта пусто.
const String _gitSha = String.fromEnvironment('GIT_SHA');

/// Версия приложения из [AppInfoProvider], хэш коммита из сборки и версия генератора (ADR-0009).
class AppInfoGenerationBuildProvider implements GenerationBuildProvider {
  const AppInfoGenerationBuildProvider(AppInfoProvider appInfo, {String commit = _gitSha})
    : _appInfo = appInfo,
      _commit = commit;

  final AppInfoProvider _appInfo;
  final String _commit;

  @override
  Future<GenerationBuild> load() async {
    try {
      final AppInfo info = await _appInfo.load();
      return GenerationBuild(app: info.display, commit: _commit, algo: GeneratorVersion.current);
    } on Object {
      return GenerationBuild(app: '', commit: _commit, algo: GeneratorVersion.current);
    }
  }
}
