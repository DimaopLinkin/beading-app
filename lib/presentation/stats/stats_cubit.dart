import 'dart:async';

import 'package:beading/core/clock.dart';
import 'package:beading/core/result.dart';
import 'package:beading/domain/stats/load_stats_overview.dart';
import 'package:beading/domain/stats/stats_overview.dart';
import 'package:beading/domain/stats/stats_range.dart';
import 'package:beading/domain/weaving/work_session.dart';
import 'package:beading/domain/weaving/work_session_repository.dart';
import 'package:beading/presentation/stats/stats_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Экран «Статистика»: период, сдвиг по периодам и итоги. Пока экран открыт, следит за сессиями: трекер пишет раз в
/// 30 с, синхронизация тоже, поэтому пересчёт откладывается на [debounce].
class StatsCubit extends Cubit<StatsState> {
  StatsCubit({
    required LoadStatsOverview load,
    required WorkSessionRepository sessions,
    required Clock clock,
    this.weekStart = DateTime.monday,
    this.debounce = const Duration(seconds: 3),
  }) : _load = load,
       _sessions = sessions,
       _clock = clock,
       super(const StatsState());

  final LoadStatsOverview _load;
  final WorkSessionRepository _sessions;
  final Clock _clock;
  final int weekStart;
  final Duration debounce;

  StreamSubscription<List<WorkSession>>? _subscription;
  Timer? _timer;
  int _generation = 0;
  bool _first = true;

  /// Границы текущего периода (для заголовков).
  StatsRange get range => StatsRange.of(state.period, _clock.now(), weekStart: weekStart, offset: state.offset);

  DateTime get now => _clock.now();

  Future<void> load() async {
    _subscription ??= _sessions.watchAll().listen((_) {
      if (_first) {
        _first = false;
        return;
      }
      _timer?.cancel();
      _timer = Timer(debounce, () => unawaited(_refresh()));
    });
    await _refresh();
  }

  Future<void> setPeriod(StatsPeriod period) async {
    if (period == state.period) {
      return;
    }
    emit(state.copyWith(period: period, offset: 0));
    await _refresh();
  }

  Future<void> previous() async {
    if (!state.canGoPrevious) {
      return;
    }
    emit(state.copyWith(offset: state.offset - 1));
    await _refresh();
  }

  Future<void> next() async {
    if (!state.canGoNext) {
      return;
    }
    emit(state.copyWith(offset: state.offset + 1));
    await _refresh();
  }

  Future<void> _refresh() async {
    final int generation = ++_generation;
    final StatsPeriod period = state.period;
    final int offset = state.offset;
    final Result<StatsOverview> result = await _load(period, offset: offset, weekStart: weekStart);
    // Пока считали, период могли сменить: устаревший ответ не показываем.
    if (isClosed || generation != _generation) {
      return;
    }
    switch (result) {
      case Success<StatsOverview>(:final StatsOverview value):
        emit(state.copyWith(status: StatsStatus.ready, overview: value));
      case Err<StatsOverview>():
        // Уже показанные данные не стираем из-за сбоя фонового пересчёта.
        if (state.overview == null) {
          emit(state.copyWith(status: StatsStatus.failed));
        }
    }
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _subscription?.cancel();
    return super.close();
  }
}
