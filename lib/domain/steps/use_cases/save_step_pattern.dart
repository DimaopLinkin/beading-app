import 'package:beading/core/failure.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/image_pattern/file_store.dart';
import 'package:beading/domain/steps/step_pattern.dart';
import 'package:beading/domain/steps/step_pattern_codec.dart';
import 'package:beading/domain/steps/step_pattern_repository.dart';
import 'package:beading/domain/steps/steps_progress.dart';

/// Сохраняет правку инструкции: одна транзакция в репозитории, потом уборка файлов картинок, на которые
/// шаги больше не ссылаются. Картинки, не привязанные ни к одному шагу, в базу не попадают.
class SaveStepPattern {
  const SaveStepPattern({
    required StepPatternRepository patterns,
    required FileStore files,
    StepsProgressStore? progress,
  }) : _patterns = patterns,
       _files = files,
       _progress = progress;

  final StepPatternRepository _patterns;
  final FileStore _files;

  /// Если задан, курсор после правки сдвигается с удалённого шага на ближайший оставшийся.
  final StepsProgressStore? _progress;

  /// [keepImageIds]: картинки, которые пока не удаляем, хотя шаги на них не ссылаются (удалённый шаг, который ещё
  /// можно вернуть).
  Future<Result<void>> call(StepPattern pattern, {Set<String> keepImageIds = const <String>{}}) async {
    // Документ, который потом не прочитать (повторный id, бусина вне палитры), в базу не пускаем.
    final Result<StepPattern> check = StepPatternCodec.decode(
      StepPatternCodec.encode(pattern),
      id: pattern.id,
      projectId: pattern.projectId,
    );
    if (check case Err<StepPattern>(:final Failure failure)) {
      return Err<void>(failure);
    }
    final Set<String> used = <String>{...pattern.referencedImageIds, ...keepImageIds};
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
    final StepsProgressStore? store = _progress;
    final StepPattern? old = previous.valueOrNull;
    if (store != null && old != null) {
      final StepsProgress? cursor = (await store.load(pattern.id)).valueOrNull;
      if (cursor != null) {
        await store.save(pattern.id, cursor.reconcile(before: old, after: pattern));
      }
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
