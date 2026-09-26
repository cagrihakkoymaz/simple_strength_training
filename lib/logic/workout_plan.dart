enum WorkoutMode {
  straight('Straight sets', 'All sets of one exercise, then the next'),
  circuit('Circuit', 'One set of each exercise per round');

  const WorkoutMode(this.label, this.description);
  final String label;
  final String description;

  static WorkoutMode fromName(String? name) => WorkoutMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => WorkoutMode.straight,
  );
}

/// One set to perform, plus how long to rest after it (0 = go straight on).
class PlannedSet {
  const PlannedSet({
    required this.exerciseIndex,
    required this.setIndex,
    required this.restAfterSeconds,
  });

  final int exerciseIndex;
  final int setIndex;
  final int restAfterSeconds;

  @override
  bool operator ==(Object other) =>
      other is PlannedSet &&
      other.exerciseIndex == exerciseIndex &&
      other.setIndex == setIndex &&
      other.restAfterSeconds == restAfterSeconds;

  @override
  int get hashCode => Object.hash(exerciseIndex, setIndex, restAfterSeconds);

  @override
  String toString() => 'PlannedSet(ex $exerciseIndex, set $setIndex, rest $restAfterSeconds)';
}

/// Orders the sets of a workout.
///
/// * [WorkoutMode.straight]: A1..A7, B1..B7, ... with [setRestSeconds] after
///   every set (including the switch to the next exercise).
/// * [WorkoutMode.circuit]: A1, B1, C1, A2, ... with [exerciseRestSeconds]
///   between exercises inside a round and [setRestSeconds] after each round.
///
/// The last set never has rest after it.
List<PlannedSet> buildPlan({
  required int exerciseCount,
  required int setsPerExercise,
  required WorkoutMode mode,
  required int setRestSeconds,
  required int exerciseRestSeconds,
}) {
  final plan = <PlannedSet>[];
  switch (mode) {
    case WorkoutMode.straight:
      for (var e = 0; e < exerciseCount; e++) {
        for (var s = 0; s < setsPerExercise; s++) {
          plan.add(PlannedSet(exerciseIndex: e, setIndex: s, restAfterSeconds: setRestSeconds));
        }
      }
    case WorkoutMode.circuit:
      for (var s = 0; s < setsPerExercise; s++) {
        for (var e = 0; e < exerciseCount; e++) {
          final endOfRound = e == exerciseCount - 1;
          plan.add(PlannedSet(
            exerciseIndex: e,
            setIndex: s,
            restAfterSeconds: endOfRound ? setRestSeconds : exerciseRestSeconds,
          ));
        }
      }
  }
  if (plan.isNotEmpty) {
    final last = plan.removeLast();
    plan.add(PlannedSet(exerciseIndex: last.exerciseIndex, setIndex: last.setIndex, restAfterSeconds: 0));
  }
  return plan;
}
