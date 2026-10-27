import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout_session.dart';
import '../state/app_state.dart';
import 'analysis_sheet.dart';
import 'widgets/common.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<AppState>().sessions;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('History (${sessions.length})'),
        actions: [
          IconButton(
            tooltip: 'Analyze history',
            onPressed: sessions.isEmpty ? null : () => showAnalysisSheet(context),
            icon: const Icon(Icons.insights),
          ),
        ],
      ),
      body: sessions.isEmpty
          ? const Center(child: Text('No workouts yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: sessions.length,
              itemBuilder: (context, i) {
                final s = sessions[i];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => SessionDetailScreen(session: s)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateTimeFmt.format(s.startedAt), style: theme.textTheme.titleMedium),
                          Text(s.mode.label, style: theme.textTheme.bodySmall),
                          const SizedBox(height: 6),
                          for (final r in s.results)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text('${r.exerciseName} · G${r.groupMax} · ${r.totalReps}/${r.targetReps}'),
                                  ),
                                  ResultBadge(unbroken: r.unbroken),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.session});
  final WorkoutSession session;

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Delete this workout?',
      message: 'It is removed from history. Your current groups are not changed '
          '(edit them in Settings if needed).',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await context.read<AppState>().deleteSession(session.id!);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = session;
    final minutes = s.finishedAt.difference(s.startedAt).inMinutes;
    return Scaffold(
      appBar: AppBar(
        title: Text(dateFmt.format(s.startedAt)),
        actions: [IconButton(onPressed: () => _delete(context), icon: const Icon(Icons.delete_outline))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            '${dateTimeFmt.format(s.startedAt)} · $minutes min\n'
            '${s.mode.label} · rest ${formatSeconds(s.setRestSeconds)}'
            '${s.exerciseRestSeconds > 0 ? ' / ${formatSeconds(s.exerciseRestSeconds)} between exercises' : ''}',
            style: theme.textTheme.bodyMedium,
          ),
          if (s.rpe != null || (s.note?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 4),
            Text(
              [if (s.rpe != null) 'Felt ${s.rpe}/10', if (s.note?.isNotEmpty ?? false) s.note!].join(' · '),
              style: theme.textTheme.bodyMedium!.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 8),
          for (final r in s.results)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(r.exerciseName, style: theme.textTheme.titleLarge)),
                        ResultBadge(unbroken: r.unbroken),
                      ],
                    ),
                    Text('Group ${r.groupMax} · ${r.totalReps}/${r.targetReps} reps · '
                        '${r.advanced ? 'moved to group ${r.groupMax + 1}' : 'stayed at group ${r.groupMax}'}'),
                    const SizedBox(height: 8),
                    SetBoxes(targets: r.targets, actuals: r.actuals),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
