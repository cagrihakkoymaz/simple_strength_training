import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

const _dbVersion = 1;

/// Starting groups requested by the user.
const defaultExercises = [
  ('Pull-ups', 11),
  ('Push-ups', 20),
  ('Squats', 30),
];

Future<Database> openAppDatabase({DatabaseFactory? factory, String? path}) async {
  final f = factory ?? databaseFactory;
  final dbPath = path ?? p.join(await f.getDatabasesPath(), 'strength_training.db');
  return f.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await createSchema(db);
        await seedExercises(db);
      },
    ),
  );
}

Future<void> createSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE exercises (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      current_max INTEGER NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER NOT NULL DEFAULT 0
    )''');
  await db.execute('''
    CREATE TABLE sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      started_at INTEGER NOT NULL,
      finished_at INTEGER NOT NULL,
      mode TEXT NOT NULL,
      set_rest_seconds INTEGER NOT NULL,
      exercise_rest_seconds INTEGER NOT NULL
    )''');
  await db.execute('''
    CREATE TABLE exercise_results (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
      exercise_id INTEGER NOT NULL,
      exercise_name TEXT NOT NULL,
      group_max INTEGER NOT NULL,
      targets TEXT NOT NULL,
      actuals TEXT NOT NULL,
      advanced INTEGER NOT NULL
    )''');
  await db.execute('CREATE INDEX idx_results_session ON exercise_results(session_id)');
  await db.execute('CREATE INDEX idx_results_exercise ON exercise_results(exercise_id)');
}

Future<void> seedExercises(DatabaseExecutor db) async {
  for (var i = 0; i < defaultExercises.length; i++) {
    final (name, max) = defaultExercises[i];
    await db.insert('exercises', {'name': name, 'current_max': max, 'active': 1, 'sort_order': i});
  }
}
