import 'package:flutter_test/flutter_test.dart';
import 'package:simple_strength_training/logic/analysis_prompt.dart';
import 'package:simple_strength_training/models/exercise.dart';

void main() {
  test('prompt lists active groups, period and workout count', () {
    final prompt = buildAnalysisPrompt(
      exercises: const [
        Exercise(id: 1, name: 'Pull-ups', currentMax: 11),
        Exercise(id: 2, name: 'Dips', currentMax: 8, active: false),
      ],
      periodLabel: 'last 4 weeks',
      workoutCount: 9,
      today: DateTime(2026, 10, 28),
    );
    expect(prompt, contains('(last 4 weeks, 9 workouts, exported 2026-10-28)'));
    expect(prompt, contains('- Pull-ups: group 11 (next workout: 5 / 5 / 4 / 4 / 4 / 3 / 3 reps)'));
    expect(prompt, isNot(contains('Dips')));
    expect(prompt, contains('rest_before_s'));
  });
}
