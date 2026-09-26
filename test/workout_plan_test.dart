import 'package:flutter_test/flutter_test.dart';
import 'package:simple_strength_training/logic/workout_plan.dart';

String render(List<PlannedSet> plan) =>
    plan.map((p) => '${'ABC'[p.exerciseIndex]}${p.setIndex + 1}:${p.restAfterSeconds}').join(' ');

void main() {
  test('straight: all sets of one exercise, then the next', () {
    final plan = buildPlan(
      exerciseCount: 2, setsPerExercise: 3, mode: WorkoutMode.straight,
      setRestSeconds: 60, exerciseRestSeconds: 10,
    );
    expect(render(plan), 'A1:60 A2:60 A3:60 B1:60 B2:60 B3:0');
  });

  test('circuit: one set of each exercise per round', () {
    final plan = buildPlan(
      exerciseCount: 3, setsPerExercise: 2, mode: WorkoutMode.circuit,
      setRestSeconds: 60, exerciseRestSeconds: 10,
    );
    expect(render(plan), 'A1:10 B1:10 C1:60 A2:10 B2:10 C2:0');
  });

  test('circuit with no rest between exercises', () {
    final plan = buildPlan(
      exerciseCount: 2, setsPerExercise: 2, mode: WorkoutMode.circuit,
      setRestSeconds: 90, exerciseRestSeconds: 0,
    );
    expect(render(plan), 'A1:0 B1:90 A2:0 B2:0');
  });

  test('empty plan', () {
    expect(
      buildPlan(exerciseCount: 0, setsPerExercise: 7, mode: WorkoutMode.circuit,
          setRestSeconds: 60, exerciseRestSeconds: 0),
      isEmpty,
    );
  });
}
