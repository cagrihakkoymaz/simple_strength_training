import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/exercise.dart';
import '../models/workout_session.dart';

const _backupFormat = 'simple_strength_training';
const _backupVersion = 2;

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

  /// History as CSV for analysis in a spreadsheet or chatbot: one row per set, oldest first.
  /// Only workouts started at or after [since], if given.
  Future<String> exportHistoryCsv({DateTime? since}) async {
    String two(int n) => n.toString().padLeft(2, '0');
    String field(String? s) {
      if (s == null) return '';
      return s.contains(RegExp('[",\r\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final lines = [
      'date,start_time,duration_min,mode,set_rest_s,exercise_rest_s,exercise,group_max,set,target,actual,'
          'set_s,rest_before_s,exercise_unbroken,advanced,rpe,note',
    ];
    final sessions = (await getSessions()).reversed.where((s) => since == null || !s.startedAt.isBefore(since));
    for (final s in sessions) {
      final t = s.startedAt;
      final date = '${t.year}-${two(t.month)}-${two(t.day)}';
      final time = '${two(t.hour)}:${two(t.minute)}';
      final minutes = s.finishedAt.difference(s.startedAt).inMinutes;
      for (final r in s.results) {
        for (var i = 0; i < r.targets.length; i++) {
          int? at(List<int?> l) => i < l.length ? l[i] : null;
          lines.add([
            date, time, minutes, s.mode.name, s.setRestSeconds, s.exerciseRestSeconds,
            field(r.exerciseName), r.groupMax, i + 1, r.targets[i], at(r.actuals) ?? 0,
            at(r.setSeconds) ?? '', at(r.restBeforeSeconds) ?? '',
            r.unbroken ? 1 : 0, r.advanced ? 1 : 0, s.rpe ?? '', field(s.note),
          ].join(','));
        }
      }
    }
    return '${lines.join('\n')}\n';
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
