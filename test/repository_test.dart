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

  test('import rejects foreign files', () async {
    await expectLater(repo.importJson('{"hello": 1}'), throwsFormatException);
    await expectLater(repo.importJson('not json'), throwsFormatException);
    expect(await repo.getExercises(), hasLength(3)); // untouched
  });
}
