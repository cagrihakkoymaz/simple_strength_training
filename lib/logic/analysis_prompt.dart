import '../data/goliaz_table.dart';
import '../models/exercise.dart';

/// Text to paste into an AI chat together with the history CSV.
///
/// Explains the program and the CSV columns, so the chatbot does not have to guess.
String buildAnalysisPrompt({
  required List<Exercise> exercises,
  required String periodLabel,
  required int workoutCount,
  required DateTime today,
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${today.year}-${two(today.month)}-${two(today.day)}';
  final groups = [
    for (final e in exercises.where((e) => e.active))
      '- ${e.name}: group ${e.currentMax} (next workout: ${setsForMax(e.currentMax).join(' / ')} reps)',
  ].join('\n');

  return '''
I train with the Goliaz Strength Training program and log every workout in my own app. The attached CSV is my workout history ($periodLabel, $workoutCount workouts, exported $date). Please analyze it and give me feedback.

How the program works:
- Each exercise (bodyweight) has a current "group" (the "max" row of the Goliaz table). One workout = the 7 target sets of that group.
- If every set reaches its target (unbroken), I usually move up one group next time; if a set is broken, I usually stay. I can override either way.
- Straight sets mode: all 7 sets of one exercise, then the next. Circuit mode: one set of each exercise per round.

CSV columns (one row per set):
- date, start_time, duration_min: when the workout started and how long it took
- mode: straight or circuit; set_rest_s / exercise_rest_s: planned rest between sets (rounds) / between exercises in a circuit
- exercise, group_max: exercise and its group in that workout; set: 1–7; target / actual: target and achieved reps
- set_s: seconds from "ready" (rest over) until I logged the set, so it includes any idle time before starting
- rest_before_s: rest I actually took before this set, after adding/removing time or skipping (empty = no rest before it)
- exercise_unbroken: 1 if all 7 sets of this exercise hit the target; advanced: 1 if I moved up a group after it
- rpe: how hard the whole workout felt, 1–10; note: my comment on the workout
- Empty set_s, rest_before_s, rpe or note means it was not recorded (older workouts have no timing).

My current groups:
$groups

Please cover:
1. Progress per exercise: how fast I move up groups, plateaus, and how often I repeat a group.
2. Where sets break: which set number and which groups, and whether it is the same pattern every time.
3. Rest and timing: does longer or shorter actual rest change whether I hit the targets? Is time of day relevant?
4. Consistency: training frequency, gaps, and days between workouts per exercise.
5. Effort and notes: how rpe and my notes relate to performance.
6. Concrete recommendations for the next 2–4 weeks (rest, frequency, when to stay or move up, recovery).

Base everything on the data; say so if there is too little data for a conclusion. Please answer in Turkish.
''';
}
