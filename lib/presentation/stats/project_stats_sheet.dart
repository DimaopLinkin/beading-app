import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/stats/project_pace.dart';
import 'package:beading/domain/stats/project_progress.dart';
import 'package:beading/domain/stats/project_stats.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/stats/duration_format.dart';
import 'package:beading/presentation/stats/project_stats_cubit.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:beading/presentation/widgets/app_list_section.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Лист «Статистика проекта»: время, прогресс, темп и последние дни. Ждёт [ProjectStatsCubit] выше.
class ProjectStatsSheet extends StatelessWidget {
  const ProjectStatsSheet({required this.now, super.key});

  /// «Сегодня» для подписей дней.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: Text(l10n.statsProjectTitle),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l10n.statsProjectDone, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      child: SafeArea(
        child: BlocBuilder<ProjectStatsCubit, ProjectStatsState>(
          builder: (context, state) {
            final ProjectStats? stats = state.stats;
            if (state.status == ProjectStatsStatus.loading) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (stats == null) {
              return Center(child: Text(l10n.statsLoadFailed));
            }
            return _Body(stats: stats, now: now);
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.stats, required this.now});

  final ProjectStats stats;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final Project project = stats.project;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final bool stitch = project.craft == Craft.crossStitch;
    final bool finished = project.status == ProjectStatus.done;

    Widget row(String label, String value) => _Line(label: label, value: value);
    Widget header(String text) => Text(text.toUpperCase(), style: TextStyle(fontSize: 13, color: secondary));

    final ProjectProgress? progress = stats.progress;
    final ProjectPace? pace = stats.pace;
    return ListView(
      padding: EdgeInsets.only(bottom: tokens.spacing.xxl),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.l, vertical: tokens.spacing.m),
          child: Row(
            children: <Widget>[
              Icon(project.craft.icon, color: secondary),
              SizedBox(width: tokens.spacing.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(project.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(
                      '${project.status.label(l10n)} · ${project.craft.label(l10n)}',
                      style: TextStyle(fontSize: 13, color: secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        AppListSection(
          header: header(l10n.statsSectionTime),
          children: stats.sessionCount == 0
              ? <Widget>[
                  Padding(
                    padding: EdgeInsets.all(tokens.spacing.l),
                    child: Column(
                      children: <Widget>[
                        Icon(AppIcons.timer, size: 32, color: secondary),
                        SizedBox(height: tokens.spacing.s),
                        Text(l10n.statsNoTimeTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          l10n.statsNoTimeText,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: secondary),
                        ),
                      ],
                    ),
                  ),
                ]
              : <Widget>[
                  CupertinoListTile(
                    title: Text(
                      formatWorkTime(l10n, stats.total),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  row(l10n.statsSessions, '${stats.sessionCount}'),
                  row(l10n.statsAverageSession, formatWorkTime(l10n, stats.averageSession)),
                  row(l10n.statsFirstDay, l10n.statsDay(stats.firstDay!)),
                  row(l10n.statsLastDay, _isToday(stats.lastDay!) ? l10n.statsToday : l10n.statsDay(stats.lastDay!)),
                ],
        ),
        if (progress != null)
          AppListSection(
            header: header(l10n.statsSectionProgress),
            children: <Widget>[
              CupertinoListTile(
                title: Text(
                  stitch || progress.rowsTotal == null
                      ? l10n.statsStitchesDone('${progress.done}', '${progress.total}')
                      : progress.done == 0
                      ? l10n.statsNotStarted
                      : l10n.statsRowOf(progress.rowsDone ?? 0, progress.rowsTotal!),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              if (stitch || progress.rowsTotal == null)
                row(l10n.statsRemaining, '${progress.remaining}')
              else
                row(l10n.statsRemaining, l10n.statsRowsLeft(progress.rowsTotal! - (progress.rowsDone ?? 0))),
              row(l10n.statsReadiness, l10n.statsPercent(progress.percent)),
            ],
          ),
        if (progress != null && stats.sessionCount > 0)
          AppListSection(
            header: header(l10n.statsSectionPace),
            footer: pace == null ? null : Text(l10n.statsPaceNote, style: TextStyle(fontSize: 13, color: secondary)),
            children: <Widget>[
              if (finished)
                CupertinoListTile(
                  title: Text(
                    l10n.statsFinished(formatWorkTime(l10n, stats.total), l10n.statsFinishedDays(stats.spanDays)),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
              else if (pace == null)
                row(l10n.statsPaceTooEarly, progress.done >= progress.total ? '' : l10n.statsPaceNeedMore)
              else ...<Widget>[
                CupertinoListTile(
                  title: Text(
                    stitch ? l10n.statsPaceStitches(_pace(pace)) : l10n.statsPaceBeads(_pace(pace)),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                row(l10n.statsPaceRemaining, l10n.statsApprox(formatWorkTime(l10n, pace.remaining))),
              ],
            ],
          ),
        if (stats.recentDays.isNotEmpty)
          AppListSection(
            header: header(l10n.statsSectionRecent),
            children: <Widget>[
              for (final MapEntry<DateTime, Duration> day in stats.recentDays)
                row(_dayLabel(l10n, day.key), formatWorkTime(l10n, day.value)),
            ],
          ),
      ],
    );
  }

  String _pace(ProjectPace pace) =>
      pace.perHour >= 10 ? pace.perHour.round().toString() : pace.perHour.toStringAsFixed(1);

  bool _isToday(DateTime day) => day.year == now.year && day.month == now.month && day.day == now.day;

  String _dayLabel(AppLocalizations l10n, DateTime day) {
    if (_isToday(day)) {
      return l10n.statsTodayCap;
    }
    final DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
    if (day == yesterday) {
      return l10n.statsYesterdayCap;
    }
    return l10n.statsDay(day);
  }
}

/// Строка списка: подпись и значение; при крупном шрифте значение переносится, а не вылезает за край.
class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 3, child: Text(label)),
        if (value.isNotEmpty)
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(color: CupertinoColors.secondaryLabel.resolveFrom(context)),
            ),
          ),
      ],
    ),
  );
}
