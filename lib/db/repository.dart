import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/exercise.dart';
import '../models/workout_session.dart';

const _backupFormat = 'simple_strength_training';
const _backupVersion = 1;

class Repository {
  Repository(this.db);

  final Database db;

  // ---- Exercises ----

  Future<List<Exercise>> getExercises({bool activeOnly = false}) async {
    final rows = await db.query(
      'exercises',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'sort_order, id',
    );
    return rows.map(Exercise.fromMap).toList();
  }

  Future<Exercise> addExercise(String name, int currentMax) async {
    final order = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COALESCE(MAX(sort_order), -1) + 1 FROM exercises'),
        ) ??
        0;
    final e = Exercise(name: name, currentMax: currentMax, sortOrder: order);
    final id = await db.insert('exercises', e.toMap()..remove('id'));
    return e.copyWith(id: id);
  }

  Future<void> updateExercise(Exercise e) =>
      db.update('exercises', e.toMap(), where: 'id = ?', whereArgs: [e.id]);

  /// History rows keep the exercise name, so they survive deletion.
  Future<void> deleteExercise(int id) => db.delete('exercises', where: 'id = ?', whereArgs: [id]);

  // ---- Sessions ----

  /// Saves the session and sets each exercise's new group in one transaction.
  /// [newMaxByExerciseId] maps exercise id -> group for the next workout.
  Future<int> saveSession(WorkoutSession s, Map<int, int> newMaxByExerciseId) {
    return db.transaction((txn) async {
      final sessionId = await txn.insert('sessions', s.toMap()..remove('id'));
      for (final r in s.results) {
        await txn.insert('exercise_results', r.toMap(sessionId)..remove('id'));
      }
      for (final entry in newMaxByExerciseId.entries) {
        await txn.update(
          'exercises',
          {'current_max': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
      return sessionId;
    });
  }

  /// Newest first.
  Future<List<WorkoutSession>> getSessions() async {
    final sessionRows = await db.query('sessions', orderBy: 'started_at DESC');
    final resultRows = await db.query('exercise_results', orderBy: 'id');
    final bySession = <int, List<ExerciseResult>>{};
    for (final r in resultRows) {
      bySession.putIfAbsent(r['session_id'] as int, () => []).add(ExerciseResult.fromMap(r));
    }
    return sessionRows
        .map((m) => WorkoutSession.fromMap(m, bySession[m['id'] as int] ?? const []))
        .toList();
  }

  Future<void> deleteSession(int id) => db.delete('sessions', where: 'id = ?', whereArgs: [id]);

  // ---- Backup ----

  Future<String> exportJson() async {
    final exercises = await db.query('exercises');
    final sessions = await db.query('sessions');
    final results = await db.query('exercise_results');
    return const JsonEncoder.withIndent('  ').convert({
      'format': _backupFormat,
      'version': _backupVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'exercises': exercises,
      'sessions': sessions,
      'exercise_results': results,
    });
  }

  /// Replaces ALL data with the backup. Throws [FormatException] if invalid.
  Future<void> importJson(String json) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const FormatException('Not a valid JSON file');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != _backupFormat) {
      throw const FormatException('Not a Strength Training backup file');
    }
    if ((decoded['version'] as int? ?? 0) > _backupVersion) {
      throw const FormatException('Backup was made by a newer app version');
    }
    final data = decoded;
    List<Map<String, Object?>> rows(String key) =>
        (data[key] as List? ?? const []).cast<Map<String, dynamic>>();

    await db.transaction((txn) async {
      await txn.delete('exercise_results');
      await txn.delete('sessions');
      await txn.delete('exercises');
      for (final r in rows('exercises')) {
        await txn.insert('exercises', r);
      }
      for (final r in rows('sessions')) {
        await txn.insert('sessions', r);
      }
      for (final r in rows('exercise_results')) {
        await txn.insert('exercise_results', r);
      }
    });
  }
}
