import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';

/// Сохраняет правку инструкции: одна транзакция в репозитории, потом уборка файлов картинок, на которые
/// шаги больше не ссылаются. Картинки, не привязанные ни к одному шагу, в базу не попадают.
class SaveStepPattern {
  const SaveStepPattern({required StepPatternRepository patterns, required FileStore files})
    : _patterns = patterns,
      _files = files;

  final StepPatternRepository _patterns;
  final FileStore _files;

  Future<Result<void>> call(StepPattern pattern) async {
    final Set<String> used = pattern.referencedImageIds;
    final List<StepImage> kept = <StepImage>[
      for (final StepImage i in pattern.images)
        if (used.contains(i.id)) i,
    ];
    final Result<StepPattern> previous = await _patterns.getByProject(pattern.projectId);
    if (previous case Err<StepPattern>(:final Failure failure) when failure is! NotFoundFailure) {
      return Err<void>(failure);
    }
    final Result<void> saved = await _patterns.save(pattern.copyWith(images: kept));
    if (saved case Err<void>()) {
      return saved;
    }
    final Set<String> keptIds = <String>{for (final StepImage i in kept) i.id};
    for (final StepImage old in previous.valueOrNull?.images ?? const <StepImage>[]) {
      if (!keptIds.contains(old.id)) {
        await _files.delete(old.path);
      }
    }
    for (final StepImage dropped in pattern.images) {
      if (!used.contains(dropped.id)) {
        await _files.delete(dropped.path);
      }
    }
    return const Success<void>(null);
  }
}
