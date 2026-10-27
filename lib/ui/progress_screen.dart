import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/training_calendar.dart';
import '../models/workout_session.dart';
import '../state/app_state.dart';
import '../state/settings.dart';
import 'widgets/common.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int? _exerciseId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final exercises = app.exercises;
    if (exercises.isEmpty) {
      return const Scaffold(body: Center(child: Text('No exercises.')));
    }
    final selected = exercises.firstWhere((e) => e.id == _exerciseId, orElse: () => exercises.first);
    final history = app.historyFor(selected.id!);

    final calendar = TrainingCalendar(
      app.sessions,
      today: DateTime.now(),
      weeklyGoal: context.watch<Settings>().weeklyGoal,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              _Stat(label: 'This week', value: '${calendar.daysThisWeek}/${calendar.weeklyGoal}'),
              _Stat(label: 'Week streak', value: '${calendar.weekStreak}'),
              _Stat(label: 'Total workouts', value: '${app.sessions.length}'),
            ],
          ),
          _CalendarCard(calendar: calendar),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final e in exercises)
                ChoiceChip(
                  label: Text(e.name),
                  selected: e.id == selected.id,
                  onSelected: (_) => setState(() => _exerciseId = e.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(label: 'Current group', value: '${selected.currentMax}'),
              _Stat(label: 'Workouts', value: '${history.length}'),
              _Stat(label: 'Unbroken', value: '${history.where((h) => h.$2.unbroken).length}'),
            ],
          ),
          const SizedBox(height: 16),
          if (history.isEmpty)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No workouts for this exercise yet.')))
          else ...[
            Text('Group over time', style: theme.textTheme.titleMedium),
            _Chart(history: history, value: (r) => r.groupMax.toDouble(), color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Total reps per workout', style: theme.textTheme.titleMedium),
            _Chart(history: history, value: (r) => r.totalReps.toDouble(), color: theme.colorScheme.tertiary),
            const SizedBox(height: 16),
            Text('Log', style: theme.textTheme.titleMedium),
            for (final (date, r) in history.reversed)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${dateFmt.format(date)} · G${r.groupMax}'),
                subtitle: Text(r.actuals.join(' · ')),
                trailing: ResultBadge(unbroken: r.unbroken),
              ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(value, style: theme.textTheme.headlineSmall),
              Text(label, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Last [_weeks] weeks: columns = weeks, rows = Mon..Sun, shade = exercises trained that day.
class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.calendar});
  final TrainingCalendar calendar;

  static const _weeks = 12;
  static const _gap = 3.0;
  static const _labelWidth = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final weeks = calendar.weekStarts(_weeks);
    final today = dayOf(calendar.today);
    final met = weeks.where(calendar.goalMet).length;

    Color fill(int exercises) => switch (exercises) {
      0 => scheme.surfaceContainerHighest,
      1 => scheme.primary.withValues(alpha: 0.4),
      2 => scheme.primary.withValues(alpha: 0.7),
      _ => scheme.primary,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last $_weeks weeks', style: theme.textTheme.titleMedium),
            Text(
              'Goal (${calendar.weeklyGoal} days) met in $met of $_weeks weeks · darker = more exercises',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final cell = ((constraints.maxWidth - _labelWidth) / _weeks - _gap).clamp(8.0, 28.0);
                Widget box({Color? color, BoxBorder? border, Widget? child}) => Container(
                  width: cell,
                  height: cell,
                  margin: const EdgeInsets.all(_gap / 2),
                  decoration: BoxDecoration(color: color, border: border, borderRadius: BorderRadius.circular(4)),
                  child: child,
                );
                return Column(
                  children: [
                    for (var d = 0; d < 7; d++)
                      Row(
                        children: [
                          SizedBox(
                            width: _labelWidth,
                            child: Text('MTWTFSS'[d], style: theme.textTheme.labelSmall),
                          ),
                          for (final w in weeks)
                            () {
                              final day = DateTime(w.year, w.month, w.day + d);
                              if (day.isAfter(today)) {
                                return box(border: Border.all(color: scheme.outlineVariant));
                              }
                              return box(
                                color: fill(calendar.exercisesOn(day)),
                                border: day == today ? Border.all(color: scheme.onSurface, width: 1.5) : null,
                              );
                            }(),
                        ],
                      ),
                    // Goal-met marker under each week.
                    Row(
                      children: [
                        const SizedBox(width: _labelWidth),
                        for (final w in weeks)
                          box(
                            child: calendar.goalMet(w)
                                ? Icon(Icons.check_circle, size: cell * 0.8, color: scheme.primary)
                                : null,
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.history, required this.value, required this.color});
  final List<(DateTime, ExerciseResult)> history;
  final double Function(ExerciseResult) value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < history.length; i++) FlSpot(i.toDouble(), value(history[i].$2)),
    ];
    final ys = spots.map((s) => s.y);
    final minY = (ys.reduce(math.min) - 1).floorToDouble();
    final maxY = (ys.reduce(math.max) + 1).ceilToDouble();
    final labelEvery = math.max(1, (history.length / 5).ceil());

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, right: 12),
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            minX: 0,
            maxX: math.max(1, spots.length - 1).toDouble(),
            gridData: const FlGridData(drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  reservedSize: 28,
                  getTitlesWidget: (v, meta) {
                    final i = v.round();
                    if (v != i || i < 0 || i >= history.length || i % labelEvery != 0) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(shortDateFmt.format(history[i].$1), style: const TextStyle(fontSize: 10)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                color: color,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
