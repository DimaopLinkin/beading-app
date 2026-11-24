import 'package:equatable/equatable.dart';

/// Чем собрано приложение: версия и сборка из Info.plist, короткий git-хэш из `--dart-define=GIT_SHA` (пусто, если
/// собрано без скрипта) и версия результата генератора ([GeneratorVersion.current]).
final class GenerationBuild extends Equatable {
  const GenerationBuild({required this.app, required this.commit, required this.algo});

  /// «0.6.0+1».
  final String app;
  final String commit;
  final int algo;

  @override
  List<Object?> get props => <Object?>[app, commit, algo];
}

abstract interface class GenerationBuildProvider {
  Future<GenerationBuild> load();
}

/// Отпечаток генерации схемы (ADR-0009): сборка плюс короткие хэши параметров и фото. Лежит в рецепте под ключом `gen`.
/// Описывает, чем схема была **создана**; правки руками после этого он не отражает.
final class GenerationStamp extends Equatable {
  const GenerationStamp({
    required this.app,
    required this.commit,
    required this.algo,
    required this.cfg,
    required this.src,
  });

  final String app;
  final String commit;
  final int algo;

  /// Хэш параметров (настройки, поворот, рамка, мазки): равные значения — одни и те же параметры.
  final String cfg;

  /// Хэш исходного фото.
  final String src;

  GenerationBuild get build => GenerationBuild(app: app, commit: commit, algo: algo);

  Map<String, Object?> toJson() => <String, Object?>{
    'app': app,
    'commit': commit,
    'algo': algo,
    'cfg': cfg,
    'src': src,
  };

  /// `null`, если записи нет или она непонятна: схема считается созданной неизвестной версией.
  static GenerationStamp? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final Object? algo = json['algo'];
    if (algo is! int) return null;
    return GenerationStamp(
      app: (json['app'] as String?) ?? '',
      commit: (json['commit'] as String?) ?? '',
      algo: algo,
      cfg: (json['cfg'] as String?) ?? '',
      src: (json['src'] as String?) ?? '',
    );
  }

  @override
  List<Object?> get props => <Object?>[app, commit, algo, cfg, src];
}
