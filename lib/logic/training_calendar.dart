import '../models/workout_session.dart';

/// Midnight of [d]'s day.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday (midnight) of the week containing [d].
DateTime weekStartOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

/// Training days per week against a weekly goal (days per week), for the Progress calendar.
class TrainingCalendar {
  TrainingCalendar(Iterable<WorkoutSession> sessions, {required this.today, required this.weeklyGoal}) {
    final ids = <DateTime, Set<int>>{};
    for (final s in sessions) {
      ids.putIfAbsent(dayOf(s.startedAt), () => {}).addAll(s.results.map((r) => r.exerciseId));
    }
    exercisesByDay = {for (final e in ids.entries) e.key: e.value.length};
  }

  final DateTime today;
  final int weeklyGoal;

  /// Distinct exercises trained per day (only days with training).
  late final Map<DateTime, int> exercisesByDay;

  DateTime get currentWeekStart => weekStartOf(today);

  /// Mondays of the last [count] weeks, oldest first; the last one is the current week.
  List<DateTime> weekStarts(int count) {
    final cur = currentWeekStart;
    return [for (var i = count - 1; i >= 0; i--) DateTime(cur.year, cur.month, cur.day - 7 * i)];
  }

  int exercisesOn(DateTime day) => exercisesByDay[dayOf(day)] ?? 0;

  int daysInWeek(DateTime weekStart) =>
      [for (var i = 0; i < 7; i++) DateTime(weekStart.year, weekStart.month, weekStart.day + i)]
          .where(exercisesByDay.containsKey)
          .length;

  bool goalMet(DateTime weekStart) => daysInWeek(weekStart) >= weeklyGoal;

  int get daysThisWeek => daysInWeek(currentWeekStart);

  /// Consecutive weeks meeting the goal, up to now. The current week counts once it meets
  /// the goal; until then it does not break the streak.
  int get weekStreak {
    if (exercisesByDay.isEmpty) return 0;
    final first = weekStartOf(exercisesByDay.keys.reduce((a, b) => a.isBefore(b) ? a : b));
    var week = currentWeekStart;
    var streak = 0;
    if (goalMet(week)) streak++;
    week = DateTime(week.year, week.month, week.day - 7);
    while (!week.isBefore(first) && goalMet(week)) {
      streak++;
      week = DateTime(week.year, week.month, week.day - 7);
    }
    return streak;
  }
}
