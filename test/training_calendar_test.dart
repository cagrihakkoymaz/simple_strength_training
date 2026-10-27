import 'package:flutter_test/flutter_test.dart';
import 'package:simple_strength_training/logic/training_calendar.dart';
import 'package:simple_strength_training/logic/workout_plan.dart';
import 'package:simple_strength_training/models/workout_session.dart';

void main() {
  WorkoutSession at(DateTime t, [List<int> exerciseIds = const [1]]) => WorkoutSession(
    startedAt: t,
    finishedAt: t.add(const Duration(minutes: 20)),
    mode: WorkoutMode.straight,
    setRestSeconds: 60,
    exerciseRestSeconds: 0,
    results: [
      for (final id in exerciseIds)
        ExerciseResult(
          exerciseId: id,
          exerciseName: 'E$id',
          groupMax: 10,
          targets: const [1, 1, 1, 1, 1, 1, 1],
          actuals: const [1, 1, 1, 1, 1, 1, 1],
          advanced: false,
        ),
    ],
  );

  // Wednesday.
  final today = DateTime(2026, 10, 28, 9);

  test('week starts on Monday', () {
    expect(weekStartOf(DateTime(2026, 11, 1, 23)), DateTime(2026, 10, 26)); // Sunday
    expect(weekStartOf(DateTime(2026, 10, 26)), DateTime(2026, 10, 26));
  });

  test('counts distinct training days and exercises per day', () {
    final cal = TrainingCalendar([
      at(DateTime(2026, 10, 26, 7), [1, 2]),
      at(DateTime(2026, 10, 26, 19), [2, 3]), // same day
      at(DateTime(2026, 10, 27, 7)),
    ], today: today, weeklyGoal: 3);
    expect(cal.daysThisWeek, 2);
    expect(cal.exercisesOn(DateTime(2026, 10, 26)), 3);
    expect(cal.goalMet(cal.currentWeekStart), isFalse);
    expect(cal.weekStarts(3), [DateTime(2026, 10, 12), DateTime(2026, 10, 19), DateTime(2026, 10, 26)]);
  });

  test('streak counts back from last week; current week only adds once met', () {
    final sessions = [
      // Two weeks ago: 2 days, last week: 2 days, three weeks ago: 1 day (breaks).
      at(DateTime(2026, 10, 5)),
      at(DateTime(2026, 10, 12)), at(DateTime(2026, 10, 14)),
      at(DateTime(2026, 10, 19)), at(DateTime(2026, 10, 25, 20)),
      at(DateTime(2026, 10, 26)),
    ];
    expect(TrainingCalendar(sessions, today: today, weeklyGoal: 2).weekStreak, 2);
    sessions.add(at(DateTime(2026, 10, 28, 7)));
    expect(TrainingCalendar(sessions, today: today, weeklyGoal: 2).weekStreak, 3);
    expect(TrainingCalendar(const [], today: today, weeklyGoal: 2).weekStreak, 0);
  });
}
