import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/analysis_prompt.dart';
import '../state/app_state.dart';

enum AnalysisPeriod {
  weeks4('4 weeks', 'last 4 weeks', 28),
  months3('3 months', 'last 3 months', 91),
  all('All', 'all history', null);

  const AnalysisPeriod(this.label, this.promptLabel, this.days);
  final String label;
  final String promptLabel;
  final int? days;

  DateTime? since(DateTime now) {
    final d = days;
    if (d == null) return null;
    return DateTime(now.year, now.month, now.day).subtract(Duration(days: d - 1));
  }
}

/// Export the history as CSV plus a ready-made prompt, for feedback from an AI chat.
Future<void> showAnalysisSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => const _AnalysisSheet(),
);

class _AnalysisSheet extends StatefulWidget {
  const _AnalysisSheet();

  @override
  State<_AnalysisSheet> createState() => _AnalysisSheetState();
}

class _AnalysisSheetState extends State<_AnalysisSheet> {
  AnalysisPeriod _period = AnalysisPeriod.weeks4;
  bool _busy = false;

  DateTime? get _since => _period.since(DateTime.now());

  int _workoutCount(AppState app) {
    final since = _since;
    return app.sessions.where((s) => since == null || !s.startedAt.isBefore(since)).length;
  }

  String _prompt(AppState app) => buildAnalysisPrompt(
    exercises: app.exercises,
    periodLabel: _period.promptLabel,
    workoutCount: _workoutCount(app),
    today: DateTime.now(),
  );

  String get _fileName => 'strength_history_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.csv';

  /// Runs [action] and reports its message or error, then closes the sheet.
  Future<void> _run(Future<String?> Function(AppState app) action) async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final message = await action(app);
      navigator.pop();
      if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (err) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Failed: $err')));
    }
  }

  Future<String?> _share(AppState app) async {
    final csv = await app.repo.exportHistoryCsv(since: _since);
    final prompt = _prompt(app);
    final file = File('${(await getTemporaryDirectory()).path}/$_fileName');
    await file.writeAsString(csv);
    // File only: apps like ChatGPT drop the file when text is shared with it. The prompt goes to the clipboard.
    await Clipboard.setData(ClipboardData(text: prompt));
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]));
    return 'Prompt copied – paste it as your message';
  }

  /// Works in any chat app: the CSV goes inside the message.
  Future<String?> _copyAsText(AppState app) async {
    final csv = await app.repo.exportHistoryCsv(since: _since);
    final prompt = _prompt(app).replaceFirst('The attached CSV', 'The CSV below');
    await Clipboard.setData(ClipboardData(text: '$prompt\n```csv\n$csv```\n'));
    return 'Prompt and data copied – paste them in the chat';
  }

  Future<String?> _save(AppState app) async {
    final csv = await app.repo.exportHistoryCsv(since: _since);
    final name = _fileName;
    final uri = await FilePicker.saveFile(
      fileName: name,
      bytes: utf8.encode(csv),
      mimeType: 'text/csv',
      dialogTitle: 'Save history',
    );
    return uri == null ? null : 'History saved: $name';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final count = _workoutCount(app);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Analyze history', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Share your history as a CSV file, then paste the copied prompt as your message. '
              'If the file does not arrive, copy everything as text instead.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SegmentedButton<AnalysisPeriod>(
              segments: [for (final p in AnalysisPeriod.values) ButtonSegment(value: p, label: Text(p.label))],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
            ),
            const SizedBox(height: 8),
            Text('$count workouts', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _busy || count == 0 ? null : () => _run(_share),
              icon: const Icon(Icons.share),
              label: const Text('Share CSV file'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _busy || count == 0 ? null : () => _run(_copyAsText),
              icon: const Icon(Icons.content_copy),
              label: const Text('Copy prompt + data as text'),
            ),
            TextButton.icon(
              onPressed: _busy || count == 0 ? null : () => _run(_save),
              icon: const Icon(Icons.save_alt),
              label: const Text('Save CSV file'),
            ),
          ],
        ),
      ),
    );
  }
}
