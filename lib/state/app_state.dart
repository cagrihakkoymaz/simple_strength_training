import 'package:flutter/foundation.dart';

import '../db/repository.dart';
import '../models/exercise.dart';
import '../models/workout_session.dart';

/// Exercises + history loaded from the database, shared by all screens.
class AppState extends ChangeNotifier {
  AppState(this.repo);

  final Repository repo;

  List<Exercise> exercises = const [];
  List<WorkoutSession> sessions = const [];
  bool loaded = false;

  List<Exercise> get activeExercises => exercises.where((e) => e.active).toList();

  Future<void> load() async {
    exercises = await repo.getExercises();
    sessions = await repo.getSessions();
    loaded = true;
    notifyListeners();
  }

  /// Most recent result for [exerciseId], or null.
  ExerciseResult? lastResultFor(int exerciseId) {
    for (final s in sessions) {
      for (final r in s.results) {
        if (r.exerciseId == exerciseId) return r;
      }
    }
    return null;
  }

  DateTime? lastDateFor(int exerciseId) {
    for (final s in sessions) {
      if (s.results.any((r) => r.exerciseId == exerciseId)) return s.startedAt;
    }
    return null;
  }

  /// Oldest first, for charts.
  List<(DateTime, ExerciseResult)> historyFor(int exerciseId) => [
    for (final s in sessions.reversed)
      for (final r in s.results)
        if (r.exerciseId == exerciseId) (s.startedAt, r),
  ];

  bool get trainedToday {
    if (sessions.isEmpty) return false;
    final d = sessions.first.startedAt;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> saveSession(WorkoutSession s, Map<int, int> newMaxByExerciseId) async {
    await repo.saveSession(s, newMaxByExerciseId);
    await load();
  }

  Future<void> deleteSession(int id) async {
    await repo.deleteSession(id);
    await load();
  }

  Future<void> addExercise(String name, int max) async {
    await repo.addExercise(name, max);
    await load();
  }

  Future<void> updateExercise(Exercise e) async {
    await repo.updateExercise(e);
    await load();
  }

  Future<void> deleteExercise(int id) async {
    await repo.deleteExercise(id);
    await load();
  }

  Future<void> importJson(String json) async {
    await repo.importJson(json);
    await load();
  }
}
