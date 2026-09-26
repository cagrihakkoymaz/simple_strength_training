import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_strength_training/db/database.dart';
import 'package:simple_strength_training/db/repository.dart';
import 'package:simple_strength_training/main.dart';
import 'package:simple_strength_training/state/app_state.dart';
import 'package:simple_strength_training/state/rest_alerts.dart';
import 'package:simple_strength_training/state/settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('full straight-sets workout with one failed set', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    // No rest so the flow does not wait on timers.
    SharedPreferences.setMockInitialValues({'set_rest_seconds': 0});
    final settings = Settings(await SharedPreferences.getInstance());
    late AppState app;
    await tester.runAsync(() async {
      final db = await openAppDatabase(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      app = AppState(Repository(db));
      await app.load();
    });

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: app),
        Provider<RestAlerts>.value(value: const NoopRestAlerts()),
      ],
      child: const StrengthApp(),
    ));

    expect(find.text('Pull-ups'), findsOneWidget);
    expect(find.text('Group 11'), findsOneWidget);

    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    // Only pull-ups.
    Finder checkbox(String name) =>
        find.ancestor(of: find.text(name), matching: find.byType(CheckboxListTile));
    await tester.tap(checkbox('Push-ups'));
    await tester.tap(checkbox('Squats'));
    await tester.pump();
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();

    // 6 successful sets.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
    }
    // Last set (goal 3) fails with 2.
    await tester.tap(find.text('Failed – enter reps'));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsWidgets);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Workout done'), findsOneWidget);
    expect(find.text('BROKEN'), findsOneWidget);
    // Broken → "Stay" preselected; user overrides to advance anyway.
    await tester.tap(find.text('Next group (12)'));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.text('Save workout'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('Group 12'), findsOneWidget);
    expect(app.sessions.single.results.single.actuals, [5, 5, 4, 4, 4, 3, 2]);
    expect(app.sessions.single.results.single.advanced, isTrue);
  });
}
