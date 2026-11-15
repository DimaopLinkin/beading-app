import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';
import 'package:beading/domain/steps/step_template.dart';
import 'package:beading/domain/steps/steps_progress.dart';

class FakeStepPatternRepository implements StepPatternRepository {
  final Map<String, StepPattern> byProject = <String, StepPattern>{};
  Failure? failNextSave;

  @override
  Future<Result<StepPattern>> getByProject(String projectId) async {
    final StepPattern? pattern = byProject[projectId];
    return pattern == null
        ? Err<StepPattern>(NotFoundFailure('нет инструкции $projectId'))
        : Success<StepPattern>(pattern);
  }

  @override
  Future<Result<void>> save(StepPattern pattern) async {
    if (failNextSave != null) {
      final Failure f = failNextSave!;
      failNextSave = null;
      return Err<void>(f);
    }
    byProject[pattern.projectId] = pattern;
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> deleteByProject(String projectId) async {
    byProject.remove(projectId);
    return const Success<void>(null);
  }
}

class FakeStepsProgressStore implements StepsProgressStore {
  final Map<String, StepsProgress> byPattern = <String, StepsProgress>{};

  @override
  Future<Result<StepsProgress?>> load(String patternId) async => Success<StepsProgress?>(byPattern[patternId]);

  @override
  Future<Result<void>> save(String patternId, StepsProgress progress) async {
    byPattern[patternId] = progress;
    return const Success<void>(null);
  }
}

class FakeStepTemplateSource implements StepTemplateSource {
  FakeStepTemplateSource(this.templates);

  final List<StepTemplate> templates;

  @override
  Future<Result<List<StepTemplate>>> all() async => Success<List<StepTemplate>>(templates);

  @override
  Future<Result<StepTemplate>> get(String id) async {
    for (final StepTemplate t in templates) {
      if (t.id == id) {
        return Success<StepTemplate>(t);
      }
    }
    return Err<StepTemplate>(NotFoundFailure('нет шаблона $id'));
  }
}
