import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout_session.dart';
import '../state/app_state.dart';
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

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final days = app.sessions.map((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day)).toSet();
    final daysThisWeek = days.where((d) => !d.isBefore(weekStart)).length;
    final daysThisMonth = days.where((d) => d.year == now.year && d.month == now.month).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              _Stat(label: 'Days this week', value: '$daysThisWeek'),
              _Stat(label: 'Days this month', value: '$daysThisMonth'),
              _Stat(label: 'Total workouts', value: '${app.sessions.length}'),
            ],
          ),
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
