import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/goliaz_table.dart';
import '../logic/progression.dart';
import '../logic/workout_plan.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import 'rest_alerts.dart';

enum WorkoutPhase { working, resting, finished }

/// Drives a single workout: which set is next, logged reps, and rest timer.
class WorkoutController extends ChangeNotifier {
  WorkoutController({
    required List<Exercise> exercises,
    required this.mode,
    required this.setRestSeconds,
    required this.exerciseRestSeconds,
    this.alerts = const NoopRestAlerts(),
    DateTime Function()? clock,
  }) : exercises = List.unmodifiable(exercises),
       _now = clock ?? DateTime.now {
    targets = [for (final e in exercises) setsForMax(e.currentMax)];
    actuals = [for (final _ in exercises) List<int?>.filled(kSetsPerGroup, null)];
    plan = buildPlan(
      exerciseCount: exercises.length,
      setsPerExercise: kSetsPerGroup,
      mode: mode,
      setRestSeconds: setRestSeconds,
      exerciseRestSeconds: exerciseRestSeconds,
    );
    startedAt = _now();
  }

  final List<Exercise> exercises;
  final WorkoutMode mode;
  final int setRestSeconds;
  final int exerciseRestSeconds;
  final RestAlerts alerts;
  final DateTime Function() _now;

  late final List<List<int>> targets;
  late final List<List<int?>> actuals;
  late final List<PlannedSet> plan;
  late final DateTime startedAt;

  int _index = 0;
  WorkoutPhase _phase = WorkoutPhase.working;
  DateTime? _restEndsAt;
  Timer? _ticker;

  WorkoutPhase get phase => _phase;
  int get stepIndex => _index;

  /// The set being performed, or (while resting) the next set.
  PlannedSet get current => plan[_index];
  Exercise get currentExercise => exercises[current.exerciseIndex];
  int get currentTarget => targets[current.exerciseIndex][current.setIndex];
  int get completedSets => actuals.expand((a) => a).where((v) => v != null).length;
  int get totalSets => plan.length;

  DateTime? get restEndsAt => _restEndsAt;
  int get restRemainingSeconds {
    final end = _restEndsAt;
    if (end == null) return 0;
    final ms = end.difference(_now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// Log the current set. [reps] defaults to the target (success).
  void logSet([int? reps]) {
    if (_phase != WorkoutPhase.working) return;
    final p = current;
    actuals[p.exerciseIndex][p.setIndex] = reps ?? currentTarget;
    if (_index == plan.length - 1) {
      _finish();
      return;
    }
    _index++;
    if (p.restAfterSeconds > 0) {
      _startRest(p.restAfterSeconds);
    }
    notifyListeners();
  }

  /// Fix an already logged set.
  void editSet(int exerciseIndex, int setIndex, int reps) {
    actuals[exerciseIndex][setIndex] = reps < 0 ? 0 : reps;
    notifyListeners();
  }

  void adjustRest(int deltaSeconds) {
    final end = _restEndsAt;
    if (_phase != WorkoutPhase.resting || end == null) return;
    _restEndsAt = end.add(Duration(seconds: deltaSeconds));
    if (restRemainingSeconds <= 0) {
      skipRest();
      return;
    }
    alerts.scheduleRestEnd(_restEndsAt!, _nextSetText());
    notifyListeners();
  }

  void skipRest() {
    if (_phase != WorkoutPhase.resting) return;
    _endRest();
    alerts.cancelRestEnd();
    notifyListeners();
  }

  /// Stop now; sets not done are recorded as 0 reps (broken).
  void finishEarly() {
    for (final a in actuals) {
      for (var i = 0; i < a.length; i++) {
        a[i] ??= 0;
      }
    }
    alerts.cancelRestEnd();
    _finish();
  }

  /// Checks the rest timer; called by the ticker and when the app resumes.
  void tick() {
    if (_phase == WorkoutPhase.resting && restRemainingSeconds <= 0) {
      _endRest();
      alerts.restEndedInApp();
    }
    notifyListeners();
  }

  List<int> actualsFor(int exerciseIndex) => [for (final v in actuals[exerciseIndex]) v ?? 0];

  bool unbrokenFor(int exerciseIndex) =>
      isUnbroken(targets[exerciseIndex], actualsFor(exerciseIndex));

  WorkoutSession buildSession(Map<int, bool> advanceByExerciseIndex) => WorkoutSession(
    startedAt: startedAt,
    finishedAt: _now(),
    mode: mode,
    setRestSeconds: setRestSeconds,
    exerciseRestSeconds: exerciseRestSeconds,
    results: [
      for (var i = 0; i < exercises.length; i++)
        ExerciseResult(
          exerciseId: exercises[i].id!,
          exerciseName: exercises[i].name,
          groupMax: exercises[i].currentMax,
          targets: targets[i],
          actuals: actualsFor(i),
          advanced: advanceByExerciseIndex[i] ?? false,
        ),
    ],
  );

  void _startRest(int seconds) {
    _phase = WorkoutPhase.resting;
    _restEndsAt = _now().add(Duration(seconds: seconds));
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => tick());
    alerts.scheduleRestEnd(_restEndsAt!, _nextSetText());
  }

  void _endRest() {
    _ticker?.cancel();
    _ticker = null;
    _restEndsAt = null;
    _phase = WorkoutPhase.working;
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    _restEndsAt = null;
    _phase = WorkoutPhase.finished;
    notifyListeners();
  }

  String _nextSetText() =>
      'Next: ${currentExercise.name} set ${current.setIndex + 1} – $currentTarget reps';

  @override
  void dispose() {
    _ticker?.cancel();
    if (_phase == WorkoutPhase.resting) alerts.cancelRestEnd();
    super.dispose();
  }
}
