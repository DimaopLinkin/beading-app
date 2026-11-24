import 'package:beading/data/settings/package_info_generation_build_provider.dart';
import 'package:beading/domain/image_to_grid/generation_stamp.dart';
import 'package:beading/domain/image_to_grid/generator_version.dart';
import 'package:beading/domain/settings/app_info.dart';
import 'package:flutter_test/flutter_test.dart';

class _Info implements AppInfoProvider {
  const _Info(this.info);

  final AppInfo? info;

  @override
  Future<AppInfo> load() async => info ?? (throw StateError('нет'));
}

void main() {
  test('сборка: версия приложения, хэш коммита и версия генератора', () async {
    final GenerationBuild build = await const AppInfoGenerationBuildProvider(
      _Info(AppInfo(version: '0.6.0', build: '1')),
      commit: 'abc123',
    ).load();
    expect(build, const GenerationBuild(app: '0.6.0 (1)', commit: 'abc123', algo: GeneratorVersion.current));
  });

  test('без версии приложения отпечаток всё равно получается', () async {
    final GenerationBuild build = await const AppInfoGenerationBuildProvider(_Info(null)).load();
    expect(build.app, '');
    expect(build.algo, GeneratorVersion.current);
  });
}
