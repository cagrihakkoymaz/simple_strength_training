import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/goliaz_table.dart';
import '../models/exercise.dart';
import '../state/app_state.dart';
import '../state/rest_alerts.dart';
import '../state/settings.dart';
import 'analysis_sheet.dart';
import 'widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<Settings>();
    final app = context.watch<AppState>();
    final theme = Theme.of(context);

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall!.copyWith(color: theme.colorScheme.primary)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          header('Rest'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                RestStepper(
                  label: 'Between sets / rounds',
                  seconds: settings.setRestSeconds,
                  onChanged: settings.setSetRestSeconds,
                ),
                RestStepper(
                  label: 'Between exercises (circuit)',
                  seconds: settings.exerciseRestSeconds,
                  onChanged: settings.setExerciseRestSeconds,
                ),
              ],
            ),
          ),
          ListTile(
            title: const Text('Alert when rest ends'),
            subtitle: Text(settings.restAlertMode.label),
            trailing: DropdownButton<RestAlertMode>(
              value: settings.restAlertMode,
              underline: const SizedBox.shrink(),
              onChanged: (m) => settings.setRestAlertMode(m!),
              items: [
                for (final m in RestAlertMode.values) DropdownMenuItem(value: m, child: Text(m.label)),
              ],
            ),
          ),
          SwitchListTile(
            title: const Text('Countdown beeps'),
            subtitle: const Text('Beep each of the last 5 seconds of rest'),
            value: settings.countdownBeeps,
            onChanged: settings.restAlertMode == RestAlertMode.soundAndVibration ? settings.setCountdownBeeps : null,
          ),
          ListTile(
            title: const Text('Other music while beeping'),
            subtitle: const Text('YouTube Music, Spotify, etc.'),
            trailing: DropdownButton<OtherAudioMode>(
              value: settings.otherAudioMode,
              underline: const SizedBox.shrink(),
              onChanged: (m) => settings.setOtherAudioMode(m!),
              items: [
                for (final m in OtherAudioMode.values) DropdownMenuItem(value: m, child: Text(m.label)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Test countdown'),
            subtitle: const Text('Uses media volume, so it works in silent / Do Not Disturb'),
            onTap: () {
              final alerts = context.read<RestAlerts>();
              alerts.stopSounds();
              alerts.countdownStarted(const Duration(seconds: kCountdownSeconds));
            },
          ),
          header('Exercises'),
          for (final e in app.exercises)
            ListTile(
              title: Text(e.name),
              subtitle: Text('Group ${e.currentMax}${e.active ? '' : ' · hidden'}'),
              leading: Icon(e.active ? Icons.fitness_center : Icons.visibility_off),
              trailing: const Icon(Icons.edit),
              onTap: () => _editExercise(context, e),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Add exercise'),
            onTap: () => _editExercise(context, null),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Program table'),
            subtitle: const Text('Goliaz Strength Training – max 2 to 49'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TableScreen())),
          ),
          header('Goal'),
          ListTile(
            title: const Text('Weekly goal'),
            subtitle: const Text('Training days per week, shown on Progress'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: settings.weeklyGoal > 1 ? () => settings.setWeeklyGoal(settings.weeklyGoal - 1) : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('${settings.weeklyGoal}', style: theme.textTheme.titleMedium),
                IconButton(
                  onPressed: settings.weeklyGoal < 7 ? () => settings.setWeeklyGoal(settings.weeklyGoal + 1) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          header('Backup'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export backup'),
            subtitle: const Text('Save all exercises and history as a JSON file'),
            onTap: () => _export(context),
          ),
          ListTile(
            leading: const Icon(Icons.insights),
            title: const Text('Analyze history'),
            subtitle: const Text('Share history as CSV with a prompt for an AI chat'),
            onTap: () => showAnalysisSheet(context),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Import backup'),
            subtitle: const Text('Replaces all current data'),
            onTap: () => _import(context),
          ),
        ],
      ),
    );
  }

  Future<void> _editExercise(BuildContext context, Exercise? e) async {
    final result = await showDialog<_ExerciseEdit>(
      context: context,
      builder: (_) => _ExerciseDialog(exercise: e),
    );
    if (result == null || !context.mounted) return;
    final app = context.read<AppState>();
    if (result.delete) {
      final ok = await confirm(
        context,
        title: 'Delete ${e!.name}?',
        message: 'Past workouts stay in history. To just hide it, turn off "Active" instead.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (ok) await app.deleteExercise(e.id!);
    } else if (e == null) {
      await app.addExercise(result.name, result.max);
    } else {
      await app.updateExercise(e.copyWith(name: result.name, currentMax: result.max, active: result.active));
    }
  }

  Future<void> _export(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await context.read<AppState>().repo.exportJson();
      final name = 'strength_backup_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.json';
      final uri = await FilePicker.saveFile(
        fileName: name,
        bytes: utf8.encode(json),
        mimeType: 'application/json',
        dialogTitle: 'Save backup',
      );
      if (uri != null) messenger.showSnackBar(SnackBar(content: Text('Backup saved: $name')));
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $err')));
    }
  }

  Future<void> _import(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final app = context.read<AppState>();
    try {
      final file = await FilePicker.pickFile(dialogTitle: 'Choose backup');
      if (file == null || !context.mounted) return;
      final ok = await confirm(
        context,
        title: 'Replace all data?',
        message: 'Everything in the app will be replaced by "${file.name}".',
        confirmLabel: 'Import',
        destructive: true,
      );
      if (!ok) return;
      await app.importJson(utf8.decode(await file.readAsBytes()));
      messenger.showSnackBar(const SnackBar(content: Text('Backup imported')));
    } on FormatException catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.message)));
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $err')));
    }
  }
}

class _ExerciseEdit {
  const _ExerciseEdit({required this.name, required this.max, required this.active, this.delete = false});
  final String name;
  final int max;
  final bool active;
  final bool delete;
}

class _ExerciseDialog extends StatefulWidget {
  const _ExerciseDialog({this.exercise});
  final Exercise? exercise;

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  late final _name = TextEditingController(text: widget.exercise?.name ?? '');
  late int _max = widget.exercise?.currentMax ?? 10;
  late bool _active = widget.exercise?.active ?? true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.exercise == null;
    return AlertDialog(
      title: Text(isNew ? 'Add exercise' : 'Edit exercise'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(isNew ? 'Max reps (group)' : 'Current group')),
              IconButton(
                onPressed: _max <= kTableMinMax ? null : () => setState(() => _max--),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_max', style: Theme.of(context).textTheme.titleLarge),
              IconButton(onPressed: () => setState(() => _max++), icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          Text(setsForMax(_max).join(' · '), style: Theme.of(context).textTheme.bodySmall),
          if (!isNew)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
        ],
      ),
      actions: [
        if (!isNew)
          TextButton(
            onPressed: () => Navigator.pop(context, _ExerciseEdit(name: '', max: 0, active: false, delete: true)),
            child: const Text('Delete', style: TextStyle(color: failColor)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _ExerciseEdit(name: _name.text.trim(), max: _max, active: _active)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// The whole Goliaz table, with each exercise's current group highlighted.
class TableScreen extends StatelessWidget {
  const TableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = context.watch<AppState>().exercises;
    final current = <int, List<String>>{};
    for (final e in exercises) {
      current.putIfAbsent(e.currentMax, () => []).add(e.name);
    }
    const cellStyle = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    return Scaffold(
      appBar: AppBar(title: const Text('Goliaz table')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Test your max reps, then do the 7 sets of that row daily with rest between them. '
            'Unbroken → next row. Broken → repeat the row. Above 49 the app scales row 49.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Table(
            columnWidths: const {0: FixedColumnWidth(48)},
            children: [
              TableRow(
                children: [
                  for (final h in ['Max', 'S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7'])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(h, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              for (final entry in goliazTable.entries)
                TableRow(
                  decoration: current.containsKey(entry.key)
                      ? BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.2))
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text('${entry.key}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    for (final v in entry.value)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text('$v', textAlign: TextAlign.center, style: cellStyle),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final e in exercises)
            Text('${e.name}: group ${e.currentMax}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
