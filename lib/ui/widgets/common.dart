import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final dateFmt = DateFormat('EEE, d MMM yyyy');
final dateTimeFmt = DateFormat('EEE, d MMM yyyy · HH:mm');
final shortDateFmt = DateFormat('d MMM');

String formatSeconds(int s) {
  final m = s ~/ 60;
  final r = s % 60;
  return m > 0 ? '$m:${r.toString().padLeft(2, '0')}' : '${r}s';
}

const successColor = Color(0xFF4CAF50);
const failColor = Color(0xFFE57373);

/// Row of 7 small boxes: target reps, optionally with actual reps.
class SetBoxes extends StatelessWidget {
  const SetBoxes({
    super.key,
    required this.targets,
    this.actuals,
    this.highlightIndex,
    this.onTap,
  });

  final List<int> targets;
  final List<int?>? actuals;
  final int? highlightIndex;
  final void Function(int setIndex)? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < targets.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _box(context, scheme, i),
            ),
          ),
      ],
    );
  }

  Widget _box(BuildContext context, ColorScheme scheme, int i) {
    final actual = actuals?[i];
    final target = targets[i];
    final done = actual != null;
    final ok = done && actual >= target;
    final bg = !done
        ? scheme.surfaceContainerHighest
        : ok
        ? successColor.withValues(alpha: 0.25)
        : failColor.withValues(alpha: 0.25);
    final border = i == highlightIndex
        ? Border.all(color: scheme.primary, width: 2)
        : Border.all(color: Colors.transparent, width: 2);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap == null || !done ? null : () => onTap!(i),
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: border),
        alignment: Alignment.center,
        child: done && !ok
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$actual', style: const TextStyle(fontWeight: FontWeight.bold, color: failColor)),
                  Text('/$target', style: Theme.of(context).textTheme.labelSmall),
                ],
              )
            : Text(
                '$target',
                style: TextStyle(fontWeight: FontWeight.bold, color: ok ? successColor : null),
              ),
      ),
    );
  }
}

class ResultBadge extends StatelessWidget {
  const ResultBadge({super.key, required this.unbroken});
  final bool unbroken;

  @override
  Widget build(BuildContext context) {
    final c = unbroken ? successColor : failColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        unbroken ? 'UNBROKEN' : 'BROKEN',
        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

/// Number picker dialog with − / + buttons. Returns null if cancelled.
Future<int?> showNumberDialog(
  BuildContext context, {
  required String title,
  required int initial,
  int min = 0,
  int max = 999,
  String? subtitle,
  String unit = 'reps',
}) {
  var value = initial.clamp(min, max);
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Widget step(int delta, IconData icon) => IconButton.filledTonal(
          iconSize: 32,
          onPressed: () => setState(() => value = (value + delta).clamp(min, max)),
          icon: Icon(icon),
        );
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle != null) Text(subtitle),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  step(-1, Icons.remove),
                  Column(
                    children: [
                      Text('$value', style: Theme.of(ctx).textTheme.displayMedium),
                      Text(unit),
                    ],
                  ),
                  step(1, Icons.add),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, value), child: const Text('Save')),
          ],
        );
      },
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'OK',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: failColor) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// "Label   [−] 60s [+]" with 15 s steps.
class RestStepper extends StatelessWidget {
  const RestStepper({super.key, required this.label, required this.seconds, required this.onChanged});
  final String label;
  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: seconds <= 0 ? null : () => onChanged(seconds - 15 < 0 ? 0 : seconds - 15),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(width: 56, child: Text(formatSeconds(seconds), textAlign: TextAlign.center)),
        IconButton(onPressed: () => onChanged(seconds + 15), icon: const Icon(Icons.add_circle_outline)),
      ],
    );
  }
}
