import 'dart:async';

import 'package:beading/core/result.dart';
import 'package:beading/domain/weaving/work_session.dart';

/// Сессии работы над проектами: основа статистики времени (T32).
abstract interface class WorkSessionRepository {
  /// Начинает сессию проекта в момент [startedAt].
  Future<Result<WorkSession>> start(String projectId, DateTime startedAt);

  /// Запоминает, что в момент [endedAt] работа ещё шла. Если приложение убьют, сессия закончится на последнем таком
  /// моменте, а не будет висеть открытой.
  Future<Result<void>> touch(String sessionId, DateTime endedAt);

  /// Все сессии проекта по порядку начала.
  Future<Result<List<WorkSession>>> byProject(String projectId);

  /// Сессии всех живых проектов по порядку начала.
  Future<Result<List<WorkSession>>> all();

  /// То же, но поток: выдаёт новое значение при каждой записи сессии (в том числе раз в 30 с от трекера и при
  /// синхронизации), поэтому потребителю нужен debounce.
  Stream<List<WorkSession>> watchAll();

  /// Добавляет проекту готовые сессии (импорт `.biser`): id им выдаются новые, времена сохраняются как есть.
  Future<Result<void>> addAll(String projectId, List<WorkSession> sessions);

  /// Сколько всего времени ушло на проект.
  Future<Result<Duration>> totalFor(String projectId);

  /// Мягко удаляет сессии проекта (вместе с проектом).
  Future<Result<void>> deleteByProject(String projectId);
}
