import 'package:beading/domain/stats/stats_overview.dart';
import 'package:beading/domain/stats/stats_range.dart';
import 'package:equatable/equatable.dart';

enum StatsStatus { loading, ready, failed }

class StatsState extends Equatable {
  const StatsState({
    this.status = StatsStatus.loading,
    this.period = StatsPeriod.week,
    this.offset = 0,
    this.overview,
  });

  final StatsStatus status;
  final StatsPeriod period;

  /// Сдвиг в периодах: 0 — текущий, −1 — прошлый.
  final int offset;
  final StatsOverview? overview;

  /// Можно листать вперёд, только если смотрим прошлое; у «всего времени» листать нечего.
  bool get canGoNext => period != StatsPeriod.all && offset < 0;
  bool get canGoPrevious => period != StatsPeriod.all;

  StatsState copyWith({StatsStatus? status, StatsPeriod? period, int? offset, StatsOverview? overview}) => StatsState(
    status: status ?? this.status,
    period: period ?? this.period,
    offset: offset ?? this.offset,
    overview: overview ?? this.overview,
  );

  @override
  List<Object?> get props => <Object?>[status, period, offset, overview];
}
