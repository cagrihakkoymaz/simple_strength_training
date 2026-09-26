import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logic/workout_plan.dart';
import '../state/rest_alerts.dart';
import '../state/workout_controller.dart';
import 'finish_screen.dart';
import 'widgets/common.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, required this.controller});
  final WorkoutController controller;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with WidgetsBindingObserver {
  WorkoutController get c => widget.controller;
  bool _navigatedToFinish = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable().ignore();
    c.addListener(_onChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable().ignore();
    c.removeListener(_onChange);
    // After a finish the FinishScreen owns the controller.
    if (!_navigatedToFinish) c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.tick();
  }

  void _onChange() {
    if (c.phase == WorkoutPhase.finished && !_navigatedToFinish) {
      _navigatedToFinish = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => FinishScreen(controller: c)),
      );
    }
  }

  Future<void> _onBack() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave workout?'),
        content: const Text('Finish now saves the sets you did; the rest count as 0 (broken).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'finish'), child: const Text('Finish now')),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'finish') {
      c.finishEarly();
    } else if (choice == 'discard') {
      Navigator.of(context).pop();
    }
  }

  Future<void> _failed() async {
    final target = c.currentTarget;
    final reps = await showNumberDialog(
      context,
      title: 'How many did you do?',
      subtitle: '${c.currentExercise.name} · set ${c.current.setIndex + 1} · goal $target',
      initial: target - 1,
    );
    if (reps != null) c.logSet(reps);
  }

  Future<void> _edit(int exerciseIndex, int setIndex) async {
    final reps = await showNumberDialog(
      context,
      title: 'Edit ${c.exercises[exerciseIndex].name} set ${setIndex + 1}',
      subtitle: 'Goal ${c.targets[exerciseIndex][setIndex]}',
      initial: c.actuals[exerciseIndex][setIndex] ?? 0,
    );
    if (reps != null) c.editSet(exerciseIndex, setIndex, reps);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: ChangeNotifierProvider.value(
        value: c,
        child: Consumer<WorkoutController>(
          builder: (context, c, _) {
            if (c.phase == WorkoutPhase.finished) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return Scaffold(
              appBar: AppBar(
                title: Text('${c.mode.label} · ${c.completedSets}/${c.totalSets}'),
                leading: IconButton(icon: const Icon(Icons.close), onPressed: _onBack),
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    LinearProgressIndicator(value: c.completedSets / c.totalSets),
                    Expanded(
                      child: c.phase == WorkoutPhase.resting ? _RestView(c: c) : _SetView(c: c, onFailed: _failed),
                    ),
                    _Overview(c: c, onEdit: _edit),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SetView extends StatelessWidget {
  const _SetView({required this.c, required this.onFailed});
  final WorkoutController c;
  final VoidCallback onFailed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = c.current;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(c.currentExercise.name, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
          Text(
            'Set ${p.setIndex + 1} of 7 · Group ${c.currentExercise.currentMax}',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          Text(
            '${c.currentTarget}',
            style: theme.textTheme.displayLarge!.copyWith(fontSize: 120, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text('reps', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const Spacer(),
          SizedBox(
            height: 72,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: successColor, foregroundColor: Colors.white),
              onPressed: () => c.logSet(),
              icon: const Icon(Icons.check, size: 32),
              label: Text('Done  ${c.currentTarget}', style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: failColor),
              onPressed: onFailed,
              icon: const Icon(Icons.close),
              label: const Text('Failed – enter reps', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestView extends StatelessWidget {
  const _RestView({required this.c});
  final WorkoutController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = c.restRemainingSeconds;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Rest', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(
            '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
            style: theme.textTheme.displayLarge!.copyWith(
              fontSize: 96,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: remaining <= kCountdownSeconds ? theme.colorScheme.error : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(onPressed: () => c.adjustRest(-15), child: const Text('−15s')),
              const SizedBox(width: 12),
              OutlinedButton(onPressed: () => c.adjustRest(15), child: const Text('+15s')),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: c.skipRest, icon: const Icon(Icons.skip_next), label: const Text('Skip')),
            ],
          ),
          const SizedBox(height: 32),
          Text('Next up', style: theme.textTheme.labelLarge),
          Text(
            '${c.currentExercise.name} · set ${c.current.setIndex + 1} · ${c.currentTarget} reps',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// All exercises × 7 sets; tap a done set to correct it.
class _Overview extends StatelessWidget {
  const _Overview({required this.c, required this.onEdit});
  final WorkoutController c;
  final void Function(int exerciseIndex, int setIndex) onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < c.exercises.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(c.exercises[i].name, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: SetBoxes(
                      targets: c.targets[i],
                      actuals: c.actuals[i],
                      highlightIndex: c.current.exerciseIndex == i ? c.current.setIndex : null,
                      onTap: (s) => onEdit(i, s),
                    ),
                  ),
                ],
              ),
            ),
          if (c.mode == WorkoutMode.circuit || c.exercises.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Tap a finished set to correct it', style: theme.textTheme.labelSmall),
            ),
        ],
      ),
    );
  }
}
