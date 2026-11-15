import 'package:beading/app/composition/core_module.dart';
import 'package:beading/app/composition/projects_module.dart';
import 'package:beading/data/steps/drift_step_pattern_repository.dart';
import 'package:beading/data/steps/drift_steps_progress_store.dart';
import 'package:beading/domain/image_pattern/image_processor.dart';
import 'package:beading/domain/steps/step_pattern_content.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';
import 'package:beading/domain/steps/step_template.dart';
import 'package:beading/domain/steps/use_cases/create_step_pattern.dart';
import 'package:beading/domain/steps/use_cases/save_step_pattern.dart';
import 'package:beading/domain/steps/use_cases/step_navigation.dart';

/// Пошаговые инструкции для техник без сетки (ADR-0008). Маршрутов и экранов пока нет: их добавят T33c и T33d.
final class StepsModule {
  StepsModule({
    required CoreModule core,
    required ProjectsModule projects,
    this.templates = const EmptyStepTemplateSource(),
  }) : _core = core,
       _projects = projects;

  final CoreModule _core;
  final ProjectsModule _projects;

  late final StepPatternRepository patterns = DriftStepPatternRepository(
    dao: _core.database.stepPatternsDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
  );

  late final StepsProgressStore progress = DriftStepsProgressStore(
    dao: _core.database.stepPatternsDao,
    deviceIds: _core.deviceIds,
    clock: _core.clock,
  );

  late final StepPatternContentCleaner contentCleaner = StepPatternContentCleaner(
    patterns: patterns,
    files: _core.fileStore,
  );

  late final StepPatternContentCloner contentCloner = StepPatternContentCloner(
    patterns: patterns,
    projects: _projects.repository,
    files: _core.fileStore,
    ids: _core.ids,
  );

  /// Встроенные шаблоны. Реализацию на ассетах подключит T33e; до того шаблонов нет.
  final StepTemplateSource templates;

  StepNavigation navigation() => StepNavigation(progress);

  SaveStepPattern savePattern() => SaveStepPattern(patterns: patterns, files: _core.fileStore, progress: progress);

  /// [processor] нужен только для «из фото»; экраны создания (T33d) передают его из платформенного слоя.
  CreateStepPattern createPattern(ImageProcessor processor) => CreateStepPattern(
    createProject: _projects.createProject(),
    projects: _projects.repository,
    patterns: patterns,
    templates: templates,
    processor: processor,
    files: _core.fileStore,
    ids: _core.ids,
  );
}
