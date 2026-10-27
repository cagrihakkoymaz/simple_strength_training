import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_strength_training/db/database.dart';
import 'package:simple_strength_training/db/repository.dart';
import 'package:simple_strength_training/logic/workout_plan.dart';
import 'package:simple_strength_training/models/workout_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Repository repo;

  setUp(() async {
    final db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    repo = Repository(db);
  });

  tearDown(() => repo.db.close());

  WorkoutSession session(int exerciseId, DateTime at, List<int> actuals) => WorkoutSession(
    startedAt: at,
    finishedAt: at.add(const Duration(minutes: 10)),
    mode: WorkoutMode.straight,
    setRestSeconds: 60,
    exerciseRestSeconds: 0,
    results: [
      ExerciseResult(
        exerciseId: exerciseId,
        exerciseName: 'Pull-ups',
        groupMax: 11,
        targets: const [5, 5, 4, 4, 4, 3, 3],
        actuals: actuals,
        advanced: true,
      ),
    ],
  );

  test('seeds the starting exercises', () async {
    final ex = await repo.getExercises();
    expect(ex.map((e) => (e.name, e.currentMax)), [('Pull-ups', 11), ('Push-ups', 20), ('Squats', 30)]);
  });

  test('saveSession stores results and updates group', () async {
    final pullups = (await repo.getExercises()).first;
    await repo.saveSession(session(pullups.id!, DateTime(2026, 9, 26), [5, 5, 4, 4, 4, 3, 3]), {pullups.id!: 12});
    await repo.saveSession(session(pullups.id!, DateTime(2026, 9, 27), [5, 5, 4, 4, 4, 3, 2]), {pullups.id!: 12});

    expect((await repo.getExercises()).first.currentMax, 12);
    final sessions = await repo.getSessions();
    expect(sessions, hasLength(2));
    expect(sessions.first.startedAt, DateTime(2026, 9, 27)); // newest first
    expect(sessions.first.results.single.unbroken, isFalse);
    expect(sessions.last.results.single.actuals, [5, 5, 4, 4, 4, 3, 3]);

    await repo.deleteSession(sessions.first.id!);
    expect(await repo.getSessions(), hasLength(1));
  });

  test('export / import round trip', () async {
    final pullups = (await repo.getExercises()).first;
    await repo.saveSession(session(pullups.id!, DateTime(2026, 9, 26), [5, 5, 4, 4, 4, 3, 3]), {pullups.id!: 12});
    await repo.addExercise('Dips', 8);
    final json = await repo.exportJson();

    await repo.deleteExercise(pullups.id!);
    await repo.importJson(json);

    final ex = await repo.getExercises();
    expect(ex.map((e) => e.name), ['Pull-ups', 'Push-ups', 'Squats', 'Dips']);
    expect(ex.first.currentMax, 12);
    final sessions = await repo.getSessions();
    expect(sessions.single.results.single.exerciseId, pullups.id);
  });

  test('history CSV has one row per set, oldest first, filtered by date', () async {
    final pullups = (await repo.getExercises()).first;
    final timed = session(pullups.id!, DateTime(2026, 9, 27, 18, 5), [5, 5, 4, 4, 4, 3, 2]);
    await repo.saveSession(
      WorkoutSession(
        startedAt: timed.startedAt,
        finishedAt: timed.finishedAt,
        mode: timed.mode,
        setRestSeconds: 60,
        exerciseRestSeconds: 0,
        rpe: 8,
        note: 'Bad sleep, "heavy"',
        results: [
          ExerciseResult(
            exerciseId: pullups.id!,
            exerciseName: 'Pull-ups',
            groupMax: 11,
            targets: const [5, 5, 4, 4, 4, 3, 3],
            actuals: const [5, 5, 4, 4, 4, 3, 2],
            advanced: false,
            setSeconds: const [20, 22, 18, 19, 21, 17, 30],
            restBeforeSeconds: const [null, 60, 60, 75, 60, 60, 90],
          ),
        ],
      ),
      {pullups.id!: 11},
    );
    await repo.saveSession(session(pullups.id!, DateTime(2026, 9, 26, 7, 30), [5, 5, 4, 4, 4, 3, 3]), {pullups.id!: 11});

    final lines = (await repo.exportHistoryCsv()).trim().split('\n');
    expect(lines, hasLength(1 + 14));
    expect(lines.first, startsWith('date,start_time,duration_min,mode'));
    // Saved before timing existed: empty timing, rating and note.
    expect(lines[1], '2026-09-26,07:30,10,straight,60,0,Pull-ups,11,1,5,5,,,1,1,,');
    expect(lines[8], '2026-09-27,18:05,10,straight,60,0,Pull-ups,11,1,5,5,20,,0,0,8,"Bad sleep, ""heavy"""');
    expect(lines.last, '2026-09-27,18:05,10,straight,60,0,Pull-ups,11,7,3,2,30,90,0,0,8,"Bad sleep, ""heavy"""');

    final recent = (await repo.exportHistoryCsv(since: DateTime(2026, 9, 27))).trim().split('\n');
    expect(recent, hasLength(1 + 7));
  });

  test('import rejects foreign files', () async {
    await expectLater(repo.importJson('{"hello": 1}'), throwsFormatException);
    await expectLater(repo.importJson('not json'), throwsFormatException);
    expect(await repo.getExercises(), hasLength(3)); // untouched
  });

  test('upgrades a v1 database and keeps its history', () async {
    final dir = await Directory.systemTemp.createTemp('strength_db');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/v1.db';
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE exercises (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, '
              'current_max INTEGER NOT NULL, active INTEGER NOT NULL DEFAULT 1, sort_order INTEGER NOT NULL DEFAULT 0)');
          await db.execute('CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, started_at INTEGER NOT NULL, '
              'finished_at INTEGER NOT NULL, mode TEXT NOT NULL, set_rest_seconds INTEGER NOT NULL, '
              'exercise_rest_seconds INTEGER NOT NULL)');
          await db.execute('CREATE TABLE exercise_results (id INTEGER PRIMARY KEY AUTOINCREMENT, '
              'session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE, exercise_id INTEGER NOT NULL, '
              'exercise_name TEXT NOT NULL, group_max INTEGER NOT NULL, targets TEXT NOT NULL, actuals TEXT NOT NULL, '
              'advanced INTEGER NOT NULL)');
          await db.insert('exercises', {'name': 'Pull-ups', 'current_max': 12});
          await db.insert('sessions', {
            'started_at': DateTime(2026, 9, 26).millisecondsSinceEpoch,
            'finished_at': DateTime(2026, 9, 26, 0, 10).millisecondsSinceEpoch,
            'mode': 'straight',
            'set_rest_seconds': 60,
            'exercise_rest_seconds': 0,
          });
          await db.insert('exercise_results', {
            'session_id': 1,
            'exercise_id': 1,
            'exercise_name': 'Pull-ups',
            'group_max': 11,
            'targets': '5,5,4,4,4,3,3',
            'actuals': '5,5,4,4,4,3,3',
            'advanced': 1,
          });
        },
      ),
    );
    await v1.close();

    final upgraded = Repository(await openAppDatabase(factory: databaseFactoryFfi, path: path));
    addTearDown(upgraded.db.close);
    final old = (await upgraded.getSessions()).single;
    expect(old.rpe, isNull);
    expect(old.results.single.actuals, [5, 5, 4, 4, 4, 3, 3]);
    expect(old.results.single.setSeconds, isEmpty);
    expect((await upgraded.getExercises()).single.currentMax, 12);
  });
}
