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
    setSeconds = [for (final _ in exercises) List<int?>.filled(kSetsPerGroup, null)];
    restBeforeSeconds = [for (final _ in exercises) List<int?>.filled(kSetsPerGroup, null)];
    plan = buildPlan(
      exerciseCount: exercises.length,
      setsPerExercise: kSetsPerGroup,
      mode: mode,
      setRestSeconds: setRestSeconds,
      exerciseRestSeconds: exerciseRestSeconds,
    );
    startedAt = _now();
    _readyAt = startedAt;
  }

  final List<Exercise> exercises;
  final WorkoutMode mode;
  final int setRestSeconds;
  final int exerciseRestSeconds;
  final RestAlerts alerts;
  final DateTime Function() _now;

  late final List<List<int>> targets;
  late final List<List<int?>> actuals;

  /// Seconds from "ready" (workout start or rest over) to logging each set.
  late final List<List<int?>> setSeconds;

  /// Rest actually taken before each set (after ±15 s and skips).
  late final List<List<int?>> restBeforeSeconds;
  late final List<PlannedSet> plan;
  late final DateTime startedAt;

  int _index = 0;
  WorkoutPhase _phase = WorkoutPhase.working;
  DateTime? _restEndsAt;
  late DateTime _readyAt;
  DateTime? _restStartedAt;
  Timer? _ticker;
  bool _countdownSignalled = false;

  WorkoutPhase get phase => _phase;
  int get stepIndex => _index;

  /// The set being performed, or (while resting) the next set.
  PlannedSet get current => plan[_index];
  Exercise get currentExercise => exercises[current.exerciseIndex];
  int get currentTarget => targets[current.exerciseIndex][current.setIndex];
  int get completedSets => actuals.expand((a) => a).where((v) => v != null).length;
  int get totalSets => plan.length;

  DateTime? get restEndsAt => _restEndsAt;
  Duration get restRemaining {
    final end = _restEndsAt;
    if (end == null) return Duration.zero;
    final left = end.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  int get restRemainingSeconds => (restRemaining.inMilliseconds / 1000).ceil();

  /// Log the current set. [reps] defaults to the target (success).
  void logSet([int? reps]) {
    if (_phase != WorkoutPhase.working) return;
    final p = current;
    final now = _now();
    actuals[p.exerciseIndex][p.setIndex] = reps ?? currentTarget;
    setSeconds[p.exerciseIndex][p.setIndex] = now.difference(_readyAt).inSeconds;
    _readyAt = now;
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
    if (_countdownSignalled && restRemaining > const Duration(seconds: kCountdownSeconds)) {
      // Extended out of the countdown window: stop beeping, count down again later.
      _countdownSignalled = false;
      alerts.stopSounds();
    }
    alerts.scheduleRestEnd(_restEndsAt!, _nextSetText());
    notifyListeners();
  }

  void skipRest() {
    if (_phase != WorkoutPhase.resting) return;
    _endRest(_now());
    alerts.cancelRestEnd();
    alerts.stopSounds();
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
    alerts.stopSounds();
    _finish();
  }

  /// Checks the rest timer; called by the ticker and when the app resumes.
  void tick() {
    if (_phase == WorkoutPhase.resting) {
      final left = restRemaining;
      if (!_countdownSignalled && left > Duration.zero && left <= const Duration(seconds: kCountdownSeconds)) {
        _countdownSignalled = true;
        alerts.countdownStarted(left);
      }
      if (left == Duration.zero) {
        // The rest ended at its end time, even if we only notice on resume.
        _endRest(_restEndsAt!);
        alerts.restEndedInApp();
      }
    }
    notifyListeners();
  }

  List<int> actualsFor(int exerciseIndex) => [for (final v in actuals[exerciseIndex]) v ?? 0];

  bool unbrokenFor(int exerciseIndex) =>
      isUnbroken(targets[exerciseIndex], actualsFor(exerciseIndex));

  WorkoutSession buildSession(Map<int, bool> advanceByExerciseIndex, {int? rpe, String? note}) => WorkoutSession(
    startedAt: startedAt,
    finishedAt: _now(),
    mode: mode,
    setRestSeconds: setRestSeconds,
    exerciseRestSeconds: exerciseRestSeconds,
    rpe: rpe,
    note: note,
    results: [
      for (var i = 0; i < exercises.length; i++)
        ExerciseResult(
          exerciseId: exercises[i].id!,
          exerciseName: exercises[i].name,
          groupMax: exercises[i].currentMax,
          targets: targets[i],
          actuals: actualsFor(i),
          advanced: advanceByExerciseIndex[i] ?? false,
          setSeconds: setSeconds[i],
          restBeforeSeconds: restBeforeSeconds[i],
        ),
    ],
  );

  void _startRest(int seconds) {
    _phase = WorkoutPhase.resting;
    _restStartedAt = _now();
    _restEndsAt = _restStartedAt!.add(Duration(seconds: seconds));
    _countdownSignalled = false;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
    alerts.scheduleRestEnd(_restEndsAt!, _nextSetText());
  }

  void _endRest(DateTime at) {
    restBeforeSeconds[current.exerciseIndex][current.setIndex] = at.difference(_restStartedAt!).inSeconds;
    _readyAt = at;
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
    if (_phase == WorkoutPhase.resting) {
      alerts.cancelRestEnd();
      alerts.stopSounds();
    }
    super.dispose();
  }
}
