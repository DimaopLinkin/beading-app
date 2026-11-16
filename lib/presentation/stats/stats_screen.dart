import 'package:beading/domain/projects/craft.dart';
import 'package:beading/domain/projects/project.dart';
import 'package:beading/domain/stats/project_progress.dart';
import 'package:beading/domain/stats/stats_overview.dart';
import 'package:beading/domain/stats/stats_range.dart';
import 'package:beading/domain/stats/work_stats.dart';
import 'package:beading/presentation/l10n/app_localizations.dart';
import 'package:beading/presentation/library/project_labels.dart';
import 'package:beading/presentation/stats/chart_buckets.dart';
import 'package:beading/presentation/stats/duration_format.dart';
import 'package:beading/presentation/stats/stats_cubit.dart';
import 'package:beading/presentation/stats/stats_state.dart';
import 'package:beading/presentation/stats/time_bar_chart.dart';
import 'package:beading/presentation/theme/app_icons.dart';
import 'package:beading/presentation/theme/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Экран «Статистика»: период, итоги, график «Время по дням» и список «По работам». Ждёт [StatsCubit] выше.
/// [onOpenProject] открывает лист статистики проекта.
class StatsScreen extends StatelessWidget {
  const StatsScreen({required this.onOpenProject, super.key});

  static const String routePath = '/stats';
  static const double maxContentWidth = 720;

  final void Function(BuildContext context, Project project) onOpenProject;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    return CupertinoPageScaffold(
      child: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, state) {
          final double width = MediaQuery.sizeOf(context).width;
          final double side = (width - maxContentWidth) / 2 > tokens.spacing.l
              ? (width - maxContentWidth) / 2
              : tokens.spacing.l;
          final EdgeInsets inset = EdgeInsets.symmetric(horizontal: side);
          return CustomScrollView(
            slivers: <Widget>[
              CupertinoSliverNavigationBar(largeTitle: Text(l10n.statsTitle)),
              SliverPadding(
                padding: inset.copyWith(top: tokens.spacing.s, bottom: tokens.spacing.s),
                sliver: SliverToBoxAdapter(child: _PeriodControl(state: state)),
              ),
              ..._body(context, state, inset),
              SliverToBoxAdapter(child: SizedBox(height: tokens.spacing.xxl)),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _body(BuildContext context, StatsState state, EdgeInsets inset) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StatsOverview? overview = state.overview;
    Widget message(String title, String text, {String? hint}) => SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: inset.add(EdgeInsets.all(tokens.spacing.xl)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(AppIcons.stats, size: 40, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
            SizedBox(height: tokens.spacing.m),
            Text(title, textAlign: TextAlign.center, style: CupertinoTheme.of(context).textTheme.navTitleTextStyle),
            SizedBox(height: tokens.spacing.s),
            Text(
              text,
              textAlign: TextAlign.center,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            if (hint != null) ...<Widget>[
              SizedBox(height: tokens.spacing.l),
              Container(
                padding: EdgeInsets.all(tokens.spacing.m),
                decoration: BoxDecoration(
                  color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(tokens.radius.m),
                ),
                child: Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ],
        ),
      ),
    );

    if (state.status == StatsStatus.loading && overview == null) {
      return const <Widget>[
        SliverFillRemaining(hasScrollBody: false, child: Center(child: CupertinoActivityIndicator())),
      ];
    }
    if (state.status == StatsStatus.failed && overview == null) {
      return <Widget>[message(l10n.statsTitle, l10n.statsLoadFailed)];
    }
    if (overview == null) {
      return const <Widget>[];
    }
    final StatsCubit cubit = context.read<StatsCubit>();
    final StatsRange range = cubit.range;
    final bool byMonths = state.period == StatsPeriod.year || state.period == StatsPeriod.all;
    final List<ChartBar> bars = chartBars(state.period, range, overview.stats.perDay, cubit.now);
    return <Widget>[
      SliverPadding(
        padding: inset,
        sliver: SliverToBoxAdapter(child: _Totals(stats: overview.stats)),
      ),
      if (overview.isEmpty)
        message(
          state.period == StatsPeriod.all ? l10n.statsEmptyTitle : l10n.statsPeriodEmptyTitle,
          state.period == StatsPeriod.all ? l10n.statsEmptyText : l10n.statsPeriodEmptyText,
          hint: state.period == StatsPeriod.all ? l10n.statsEmptyHint : null,
        )
      else ...<Widget>[
        SliverPadding(
          padding: inset.copyWith(top: tokens.spacing.m),
          sliver: SliverToBoxAdapter(
            child: _Card(
              title: byMonths ? l10n.statsChartMonths : l10n.statsChartDays,
              child: TimeBarChart(bars: bars, byMonths: byMonths, weekdayLabels: state.period == StatsPeriod.week),
            ),
          ),
        ),
        SliverPadding(
          padding: inset.copyWith(top: tokens.spacing.l),
          sliver: SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: tokens.spacing.m, bottom: tokens.spacing.xs),
              child: Text(
                l10n.statsByProjects.toUpperCase(),
                style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: inset,
          sliver: SliverList.separated(
            itemCount: overview.rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _ProjectRow(row: overview.rows[i], onTap: () => onOpenProject(context, overview.rows[i].project)),
          ),
        ),
      ],
    ];
  }
}

class _PeriodControl extends StatelessWidget {
  const _PeriodControl({required this.state});

  final StatsState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final StatsCubit cubit = context.read<StatsCubit>();
    final StatsRange range = cubit.range;
    final (String title, String? subtitle) = _titles(l10n, state, range, cubit.now);
    Widget segment(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1)),
    );
    Widget arrow(IconData icon, String label, VoidCallback onTap, {required bool enabled}) => CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.square(tokens.minTapTarget),
      onPressed: enabled ? onTap : null,
      child: Semantics(label: label, child: Icon(icon)),
    );
    return Column(
      children: <Widget>[
        if (MediaQuery.textScalerOf(context).scale(16) > 24)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: tokens.spacing.s,
            runSpacing: tokens.spacing.s,
            children: <Widget>[
              for (final (StatsPeriod, String) p in <(StatsPeriod, String)>[
                (StatsPeriod.week, l10n.statsPeriodWeek),
                (StatsPeriod.month, l10n.statsPeriodMonth),
                (StatsPeriod.year, l10n.statsPeriodYear),
                (StatsPeriod.all, l10n.statsPeriodAll),
              ])
                CupertinoButton(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spacing.m),
                  minimumSize: Size.square(tokens.minTapTarget),
                  color: state.period == p.$1
                      ? CupertinoTheme.of(context).primaryColor
                      : CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(tokens.radius.capsule),
                  onPressed: () => cubit.setPeriod(p.$1),
                  child: Text(
                    p.$2,
                    style: TextStyle(
                      color: state.period == p.$1 ? CupertinoColors.white : CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<StatsPeriod>(
              groupValue: state.period,
              onValueChanged: (p) {
                if (p != null) {
                  cubit.setPeriod(p);
                }
              },
              children: <StatsPeriod, Widget>{
                StatsPeriod.week: segment(l10n.statsPeriodWeek),
                StatsPeriod.month: segment(l10n.statsPeriodMonth),
                StatsPeriod.year: segment(l10n.statsPeriodYear),
                StatsPeriod.all: segment(l10n.statsPeriodAll),
              },
            ),
          ),
        SizedBox(height: tokens.spacing.s),
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final double v = d.primaryVelocity ?? 0;
            if (v > 200) {
              cubit.previous();
            } else if (v < -200) {
              cubit.next();
            }
          },
          child: Row(
            children: <Widget>[
              arrow(AppIcons.back, l10n.statsPreviousPeriod, cubit.previous, enabled: state.canGoPrevious),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
                      ),
                  ],
                ),
              ),
              arrow(AppIcons.forward, l10n.statsNextPeriod, cubit.next, enabled: state.canGoNext),
            ],
          ),
        ),
      ],
    );
  }

  (String, String?) _titles(AppLocalizations l10n, StatsState state, StatsRange range, DateTime now) {
    switch (state.period) {
      case StatsPeriod.week:
        final DateTime last = DateTime(range.end.year, range.end.month, range.end.day - 1);
        final String title = state.offset == 0
            ? l10n.statsThisWeek
            : state.offset == -1
            ? l10n.statsLastWeek
            : l10n.statsWeekRange(range.start, last);
        return (title, l10n.statsWeekRange(range.start, last));
      case StatsPeriod.month:
        return (
          state.offset == 0 ? l10n.statsThisMonth : _capital(l10n.statsMonthName(range.start)),
          l10n.statsMonthYear(range.start),
        );
      case StatsPeriod.year:
        return (l10n.statsYearTitle(range.start.year), l10n.statsByMonths);
      case StatsPeriod.all:
        return (l10n.statsPeriodAll, l10n.statsByMonths);
    }
  }

  String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Totals extends StatelessWidget {
  const _Totals({required this.stats});

  final WorkStats stats;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final List<(String, String)> cells = <(String, String)>[
      (l10n.statsTotalTime, formatWorkTime(l10n, stats.total)),
      (l10n.statsWorkDays, '${stats.daysWithWork}'),
      (l10n.statsAveragePerDay, formatWorkTime(l10n, stats.averagePerWorkDay)),
      (l10n.statsLongestSession, formatWorkTime(l10n, stats.longestSession)),
    ];
    Widget cell((String, String) c) => Expanded(
      child: _Card(
        small: true,
        title: c.$1,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            c.$2,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
    final bool tall = MediaQuery.textScalerOf(context).scale(16) > 24;
    if (tall) {
      return Column(
        children: <Widget>[
          for (final (String, String) c in cells) ...<Widget>[
            Row(children: <Widget>[cell(c)]),
            SizedBox(height: tokens.spacing.s),
          ],
        ],
      );
    }
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            cell(cells[0]),
            SizedBox(width: tokens.spacing.s),
            cell(cells[1]),
          ],
        ),
        SizedBox(height: tokens.spacing.s),
        Row(
          children: <Widget>[
            cell(cells[2]),
            SizedBox(width: tokens.spacing.s),
            cell(cells[3]),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.small = false});

  final String title;
  final Widget child;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final AppTokensData tokens = context.tokens;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spacing.m),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(tokens.radius.m),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel.resolveFrom(context))),
          SizedBox(height: small ? tokens.spacing.xs : tokens.spacing.s),
          child,
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.row, required this.onTap});

  final ProjectTimeRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppTokensData tokens = context.tokens;
    final Color secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final Project project = row.project;
    final ProjectProgress? progress = row.progress;
    final String? done = progress == null
        ? null
        : project.craft == Craft.crossStitch
        ? l10n.statsStitchesDone(formatCount(progress.done), formatCount(progress.total))
        : progress.rowsTotal == null
        ? null
        : l10n.statsRowOf(progress.rowsDone ?? 0, progress.rowsTotal!);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.m),
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
          borderRadius: BorderRadius.circular(tokens.radius.m),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(tokens.radius.s),
              ),
              child: Icon(project.craft.icon, color: secondary),
            ),
            SizedBox(width: tokens.spacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    project.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(project.craft.label(l10n), style: TextStyle(fontSize: 13, color: secondary)),
                  if (done != null) Text(done, style: TextStyle(fontSize: 13, color: secondary)),
                  if (progress != null) ...<Widget>[
                    SizedBox(height: tokens.spacing.xs),
                    _Bar(fraction: progress.fraction),
                  ],
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.s),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(formatWorkTime(l10n, row.periodTime), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  l10n.statsRowTotal(formatWorkTime(l10n, row.totalTime)),
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
                if (progress != null)
                  Text(l10n.statsPercent(progress.percent), style: TextStyle(fontSize: 13, color: secondary)),
              ],
            ),
            Icon(AppIcons.forward, size: 16, color: CupertinoColors.tertiaryLabel.resolveFrom(context)),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: SizedBox(
      height: 4,
      child: Stack(
        children: <Widget>[
          ColoredBox(color: CupertinoColors.systemFill.resolveFrom(context), child: const SizedBox.expand()),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: ColoredBox(color: CupertinoTheme.of(context).primaryColor, child: const SizedBox.expand()),
          ),
        ],
      ),
    ),
  );
}
