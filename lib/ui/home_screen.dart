import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/goliaz_table.dart';
import '../logic/workout_plan.dart';
import '../models/exercise.dart';
import '../state/app_state.dart';
import '../state/rest_alerts.dart';
import '../state/settings.dart';
import '../state/workout_controller.dart';
import 'widgets/common.dart';
import 'workout_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final exercises = app.activeExercises;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      floatingActionButton: exercises.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showStartSheet(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start workout'),
            ),
      body: exercises.isEmpty
          ? const Center(child: Text('No active exercises.\nAdd one in Settings.', textAlign: TextAlign.center))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
              children: [
                if (app.trainedToday)
                  Card(
                    color: successColor.withValues(alpha: 0.15),
                    child: const ListTile(
                      leading: Icon(Icons.check_circle, color: successColor),
                      title: Text('You already trained today'),
                    ),
                  ),
                for (final e in exercises) _ExerciseCard(exercise: e),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Do the 7 sets of your group daily. Unbroken → next group. Broken → repeat.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }

  void _showStartSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _StartWorkoutSheet(),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.exercise});
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final targets = setsForMax(exercise.currentMax);
    final last = app.lastResultFor(exercise.id!);
    final lastDate = app.lastDateFor(exercise.id!);
    final total = targets.fold(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(exercise.name, style: theme.textTheme.titleLarge)),
                Chip(label: Text('Group ${exercise.currentMax}')),
              ],
            ),
            const SizedBox(height: 8),
            SetBoxes(targets: targets),
            const SizedBox(height: 8),
            Text('Total $total reps'
                '${isExtrapolated(exercise.currentMax) ? ' · beyond table (extrapolated)' : ''}',
                style: theme.textTheme.bodySmall),
            if (last != null && lastDate != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Last: ${dateFmt.format(lastDate)} · G${last.groupMax} · '
                      '${last.totalReps}/${last.targetReps}  ',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ResultBadge(unbroken: last.unbroken),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StartWorkoutSheet extends StatefulWidget {
  const _StartWorkoutSheet();

  @override
  State<_StartWorkoutSheet> createState() => _StartWorkoutSheetState();
}

class _StartWorkoutSheetState extends State<_StartWorkoutSheet> {
  late WorkoutMode _mode;
  late Set<int> _selected;

  @override
  void initState() {
    super.initState();
    _mode = context.read<Settings>().lastMode;
    _selected = context.read<AppState>().activeExercises.map((e) => e.id!).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Settings>();
    final exercises = context.watch<AppState>().activeExercises;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Start workout', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<WorkoutMode>(
              segments: [
                for (final m in WorkoutMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(_mode.description, style: theme.textTheme.bodySmall),
            ),
            for (final e in exercises)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _selected.contains(e.id),
                title: Text(e.name),
                subtitle: Text('Group ${e.currentMax}: ${setsForMax(e.currentMax).join(' · ')}'),
                onChanged: (v) => setState(() => v! ? _selected.add(e.id!) : _selected.remove(e.id)),
              ),
            const Divider(),
            RestStepper(
              label: _mode == WorkoutMode.straight ? 'Rest between sets' : 'Rest between rounds',
              seconds: settings.setRestSeconds,
              onChanged: settings.setSetRestSeconds,
            ),
            if (_mode == WorkoutMode.circuit)
              RestStepper(
                label: 'Rest between exercises',
                seconds: settings.exerciseRestSeconds,
                onChanged: settings.setExerciseRestSeconds,
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _selected.isEmpty ? null : () => _start(exercises),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Go'),
            ),
          ],
        ),
      ),
    );
  }

  void _start(List<Exercise> exercises) {
    final settings = context.read<Settings>();
    settings.setLastMode(_mode);
    final controller = WorkoutController(
      exercises: exercises.where((e) => _selected.contains(e.id)).toList(),
      mode: _mode,
      setRestSeconds: settings.setRestSeconds,
      exerciseRestSeconds: _mode == WorkoutMode.circuit ? settings.exerciseRestSeconds : 0,
      alerts: context.read<RestAlerts>(),
    );
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute<void>(builder: (_) => WorkoutScreen(controller: controller)));
  }
}
