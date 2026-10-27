import 'package:flutter_test/flutter_test.dart';
import 'package:simple_strength_training/logic/workout_plan.dart';
import 'package:simple_strength_training/models/exercise.dart';
import 'package:simple_strength_training/state/rest_alerts.dart';
import 'package:simple_strength_training/state/workout_controller.dart';

class FakeAlerts implements RestAlerts {
  final scheduled = <DateTime>[];
  int cancels = 0;
  int inApp = 0;
  final countdowns = <Duration>[];
  int stops = 0;
  @override
  Future<void> scheduleRestEnd(DateTime at, String body) async => scheduled.add(at);
  @override
  Future<void> cancelRestEnd() async => cancels++;
  @override
  void restEndedInApp() => inApp++;
  @override
  void countdownStarted(Duration remaining) => countdowns.add(remaining);
  @override
  void stopSounds() => stops++;
}

void main() {
  late DateTime now;
  late FakeAlerts alerts;
  const pullups = Exercise(id: 1, name: 'Pull-ups', currentMax: 11);
  const pushups = Exercise(id: 2, name: 'Push-ups', currentMax: 20);

  WorkoutController make(WorkoutMode mode, {int rest = 60}) => WorkoutController(
    exercises: const [pullups, pushups],
    mode: mode,
    setRestSeconds: rest,
    exerciseRestSeconds: 0,
    alerts: alerts,
    clock: () => now,
  );

  setUp(() {
    now = DateTime(2026, 9, 26, 10);
    alerts = FakeAlerts();
  });

  test('targets come from the table', () {
    final c = make(WorkoutMode.straight);
    expect(c.targets[0], [5, 5, 4, 4, 4, 3, 3]);
    expect(c.targets[1], [8, 9, 8, 8, 8, 6, 3]);
    c.dispose();
  });

  test('success, rest, timer end, next set', () {
    final c = make(WorkoutMode.straight);
    c.logSet();
    expect(c.actuals[0][0], 5);
    expect(c.phase, WorkoutPhase.resting);
    expect(c.restRemainingSeconds, 60);
    expect(alerts.scheduled.single, now.add(const Duration(seconds: 60)));
    expect(c.current.setIndex, 1); // next set shown during rest

    now = now.add(const Duration(seconds: 30));
    c.adjustRest(15);
    expect(c.restRemainingSeconds, 45);

    now = now.add(const Duration(seconds: 45));
    c.tick();
    expect(c.phase, WorkoutPhase.working);
    expect(alerts.inApp, 1);
    c.dispose();
  });

  test('failed set records real reps and workout continues', () {
    final c = make(WorkoutMode.circuit, rest: 0);
    c.logSet(3); // pull-ups set 1 failed (goal 5)
    expect(c.phase, WorkoutPhase.working);
    expect(c.currentExercise.name, 'Push-ups');
    c.logSet();
    expect(c.currentExercise.name, 'Pull-ups');
    expect(c.current.setIndex, 1);
    expect(c.unbrokenFor(0), isFalse);
    c.dispose();
  });

  test('complete workout, edit a set, build session', () {
    final c = make(WorkoutMode.straight, rest: 0);
    for (var i = 0; i < 14; i++) {
      c.logSet();
    }
    expect(c.phase, WorkoutPhase.finished);
    expect(c.unbrokenFor(0), isTrue);
    c.editSet(1, 6, 1);
    expect(c.unbrokenFor(1), isFalse);
    final s = c.buildSession({0: true, 1: false});
    expect(s.results[0].advanced, isTrue);
    expect(s.results[1].actuals.last, 1);
    expect(s.results[1].unbroken, isFalse);
    c.dispose();
  });

  test('finish early fills remaining sets with 0', () {
    final c = make(WorkoutMode.straight);
    c.logSet();
    c.finishEarly();
    expect(c.phase, WorkoutPhase.finished);
    expect(c.actualsFor(0), [5, 0, 0, 0, 0, 0, 0]);
    expect(alerts.cancels, greaterThan(0));
    c.dispose();
  });

  test('countdown fires once in the last 5 s and restarts after +15 s', () {
    final c = make(WorkoutMode.straight);
    c.logSet();
    now = now.add(const Duration(seconds: 54));
    c.tick();
    expect(alerts.countdowns, isEmpty);

    now = now.add(const Duration(milliseconds: 1100)); // 4.9 s left
    c.tick();
    c.tick();
    expect(alerts.countdowns, [const Duration(milliseconds: 4900)]);

    c.adjustRest(15); // back to 19.9 s: stop beeping
    expect(alerts.stops, 1);

    now = now.add(const Duration(seconds: 15));
    c.tick();
    expect(alerts.countdowns, hasLength(2));

    now = now.add(const Duration(seconds: 5));
    c.tick();
    expect(c.phase, WorkoutPhase.working);
    expect(alerts.inApp, 1);
    c.dispose();
  });

  test('skipping rest stops sounds', () {
    final c = make(WorkoutMode.straight);
    c.logSet();
    c.skipRest();
    expect(alerts.stops, 1);
    expect(c.phase, WorkoutPhase.working);
    c.dispose();
  });

  test('records set times and the rest actually taken', () {
    final c = make(WorkoutMode.straight);
    now = now.add(const Duration(seconds: 20));
    c.logSet(); // set 1 took 20 s
    now = now.add(const Duration(seconds: 30));
    c.adjustRest(15); // 75 s rest in total
    // App was in background; we notice the end 100 s later.
    now = now.add(const Duration(seconds: 100));
    c.tick();
    expect(c.restBeforeSeconds[0][1], 75);
    now = now.add(const Duration(seconds: 10)); // 65 s after the rest ended
    c.logSet();
    expect(c.setSeconds[0].take(2), [20, 65]);

    now = now.add(const Duration(seconds: 40));
    c.skipRest();
    expect(c.restBeforeSeconds[0][2], 40);
    now = now.add(const Duration(seconds: 15));
    c.logSet();

    final r = c.buildSession({0: false}, rpe: 7, note: 'tired').results.first;
    expect(r.setSeconds.take(3), [20, 65, 15]);
    expect(r.restBeforeSeconds.take(3), [null, 75, 40]);
    expect(r.setSeconds[3], isNull);
    c.dispose();
  });
}
