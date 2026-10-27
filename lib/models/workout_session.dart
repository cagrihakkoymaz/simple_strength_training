import '../logic/progression.dart';
import '../logic/workout_plan.dart';

/// Result of one exercise (7 sets) inside a session.
class ExerciseResult {
  const ExerciseResult({
    this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.groupMax,
    required this.targets,
    required this.actuals,
    required this.advanced,
    this.setSeconds = const [],
    this.restBeforeSeconds = const [],
  });

  final int? id;
  final int exerciseId;

  /// Stored so history stays readable if the exercise is renamed/deleted.
  final String exerciseName;
  final int groupMax;
  final List<int> targets;
  final List<int> actuals;

  /// Whether the user chose to move to the next group after this session.
  final bool advanced;

  /// Per set: seconds from "ready" (rest over) to the set being logged. Null = not timed.
  /// Empty for workouts saved before timing was recorded.
  final List<int?> setSeconds;

  /// Per set: rest actually taken before it, after ±15 s and skips. Null = no rest before it.
  final List<int?> restBeforeSeconds;

  bool get unbroken => isUnbroken(targets, actuals);
  int get totalReps => actuals.fold(0, (a, b) => a + b);
  int get targetReps => targets.fold(0, (a, b) => a + b);

  Map<String, Object?> toMap(int sessionId) => {
    'id': id,
    'session_id': sessionId,
    'exercise_id': exerciseId,
    'exercise_name': exerciseName,
    'group_max': groupMax,
    'targets': targets.join(','),
    'actuals': actuals.join(','),
    'advanced': advanced ? 1 : 0,
    'set_seconds': setSeconds.map((v) => v ?? '').join(','),
    'rest_before_seconds': restBeforeSeconds.map((v) => v ?? '').join(','),
  };

  factory ExerciseResult.fromMap(Map<String, Object?> m) => ExerciseResult(
    id: m['id'] as int?,
    exerciseId: m['exercise_id'] as int,
    exerciseName: m['exercise_name'] as String,
    groupMax: m['group_max'] as int,
    targets: _parseList(m['targets'] as String),
    actuals: _parseList(m['actuals'] as String),
    advanced: (m['advanced'] as int) == 1,
    setSeconds: _parseOptionalList(m['set_seconds'] as String?),
    restBeforeSeconds: _parseOptionalList(m['rest_before_seconds'] as String?),
  );

  static List<int> _parseList(String s) =>
      s.isEmpty ? const [] : s.split(',').map(int.parse).toList();

  static List<int?> _parseOptionalList(String? s) =>
      s == null || s.isEmpty ? const [] : s.split(',').map(int.tryParse).toList();
}

class WorkoutSession {
  const WorkoutSession({
    this.id,
    required this.startedAt,
    required this.finishedAt,
    required this.mode,
    required this.setRestSeconds,
    required this.exerciseRestSeconds,
    required this.results,
    this.rpe,
    this.note,
  });

  final int? id;
  final DateTime startedAt;
  final DateTime finishedAt;
  final WorkoutMode mode;
  final int setRestSeconds;
  final int exerciseRestSeconds;
  final List<ExerciseResult> results;

  /// How hard the workout felt, 1–10. Null = not rated.
  final int? rpe;
  final String? note;

  bool get allUnbroken => results.every((r) => r.unbroken);

  Map<String, Object?> toMap() => {
    'id': id,
    'started_at': startedAt.millisecondsSinceEpoch,
    'finished_at': finishedAt.millisecondsSinceEpoch,
    'mode': mode.name,
    'set_rest_seconds': setRestSeconds,
    'exercise_rest_seconds': exerciseRestSeconds,
    'rpe': rpe,
    'note': note,
  };

  factory WorkoutSession.fromMap(Map<String, Object?> m, List<ExerciseResult> results) =>
      WorkoutSession(
        id: m['id'] as int?,
        startedAt: DateTime.fromMillisecondsSinceEpoch(m['started_at'] as int),
        finishedAt: DateTime.fromMillisecondsSinceEpoch(m['finished_at'] as int),
        mode: WorkoutMode.fromName(m['mode'] as String?),
        setRestSeconds: m['set_rest_seconds'] as int,
        exerciseRestSeconds: m['exercise_rest_seconds'] as int,
        results: results,
        rpe: m['rpe'] as int?,
        note: m['note'] as String?,
      );
}
