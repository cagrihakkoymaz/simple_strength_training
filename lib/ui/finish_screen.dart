import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/goliaz_table.dart';
import '../logic/progression.dart';
import '../state/app_state.dart';
import '../state/workout_controller.dart';
import 'widgets/common.dart';

class FinishScreen extends StatefulWidget {
  const FinishScreen({super.key, required this.controller});
  final WorkoutController controller;

  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  WorkoutController get c => widget.controller;
  late final Map<int, bool> _advance = {
    for (var i = 0; i < c.exercises.length; i++) i: defaultAdvance(c.targets[i], c.actualsFor(i)),
  };
  bool _saving = false;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final session = c.buildSession(_advance);
    final newMax = {
      for (var i = 0; i < c.exercises.length; i++)
        c.exercises[i].id!: nextMax(c.exercises[i].currentMax, advance: _advance[i]!),
    };
    await context.read<AppState>().saveSession(session, newMax);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout saved 💪')));
  }

  Future<void> _discard() async {
    final ok = await confirm(
      context,
      title: 'Discard workout?',
      message: 'Nothing from this workout will be saved.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _edit(int e, int s) async {
    final reps = await showNumberDialog(
      context,
      title: 'Edit ${c.exercises[e].name} set ${s + 1}',
      subtitle: 'Goal ${c.targets[e][s]}',
      initial: c.actuals[e][s] ?? 0,
    );
    if (reps == null) return;
    final wasDefault = _advance[e] == defaultAdvance(c.targets[e], c.actualsFor(e));
    c.editSet(e, s, reps);
    setState(() {
      // Keep the toggle in sync with the result unless the user changed it.
      if (wasDefault) _advance[e] = defaultAdvance(c.targets[e], c.actualsFor(e));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _discard();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Workout done'), automaticallyImplyLeading: false),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (var i = 0; i < c.exercises.length; i++) _resultCard(theme, i),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Save workout', style: TextStyle(fontSize: 18)),
            ),
            TextButton(onPressed: _saving ? null : _discard, child: const Text('Discard')),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(ThemeData theme, int i) {
    final e = c.exercises[i];
    final actuals = c.actualsFor(i);
    final total = actuals.fold(0, (a, b) => a + b);
    final target = c.targets[i].fold(0, (a, b) => a + b);
    final unbroken = c.unbrokenFor(i);
    final next = e.currentMax + 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(e.name, style: theme.textTheme.titleLarge)),
                ResultBadge(unbroken: unbroken),
              ],
            ),
            Text('Group ${e.currentMax} · $total / $target reps', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            SetBoxes(targets: c.targets[i], actuals: c.actuals[i], onTap: (s) => _edit(i, s)),
            const SizedBox(height: 12),
            Text('Next workout:', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, icon: const Icon(Icons.trending_up), label: Text('Next group ($next)')),
                  ButtonSegment(value: false, icon: const Icon(Icons.replay), label: Text('Stay (${e.currentMax})')),
                ],
                selected: {_advance[i]!},
                onSelectionChanged: (s) => setState(() => _advance[i] = s.first),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sets: ${setsForMax(_advance[i]! ? next : e.currentMax).join(' · ')}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
