# CLAUDE.md

Personal Flutter app for the **Goliaz Strength Training** program. Its first user is the owner, on a
Samsung S22 FE (Android). Keep it simple, offline, and fast to use with sweaty hands between sets.

## The program (domain rules – do not change without being asked)
- Source table: `docs/program_image.jpeg`, transcribed to `lib/data/goliaz_table.dart`
  (max 2–49 → 7 target sets each). Any change to the table must match the image. `test/goliaz_table_test.dart` spot-checks it.
- Each exercise has a **current group** (= a "Max" row). One workout = the 7 sets of that row, with rest between sets.
- **Unbroken** (every set ≥ target) → the finish screen preselects *Next group (max+1)*; the user can still choose *Stay*.
- **Broken** → preselects *Stay*; the user can still override. A failed set records the real reps and the workout goes on.
- Above 49: `round(row49[i] * max / 49)` (extrapolation chosen by the user). Below 2: row 2.
- Starting groups (seeded on first launch): Pull-ups 11, Push-ups 20, Squats 30. Users can add or hide exercises.
- Workout modes, chosen per workout (the last choice is remembered):
  - *Straight sets*: A1..A7, B1..B7, with the set rest after every set.
  - *Circuit*: A1 B1 C1 → round rest → A2…; a separate "between exercises" rest (default 0 s) applies inside a round.
- Rest defaults: 60 s between sets/rounds, adjustable in Settings, on the start sheet, and with ±15 s while resting.

## Architecture
```
lib/
  data/goliaz_table.dart      table + setsForMax()
  logic/                      pure Dart, unit tested
    progression.dart          isUnbroken / defaultAdvance / nextMax
    workout_plan.dart         WorkoutMode + buildPlan() → ordered PlannedSet list with rest-after
    analysis_prompt.dart      prompt (program + CSV columns + current groups) for AI feedback
    training_calendar.dart    training days per week, weekly goal met, week streak (Progress calendar)
  models/                     Exercise, WorkoutSession, ExerciseResult (toMap/fromMap)
  db/database.dart            sqflite schema v2 + seed; bump _dbVersion and add an onUpgrade step for schema changes
  db/repository.dart          all SQL, session save (transaction also updates groups), JSON export/import, history CSV
  state/
    app_state.dart            ChangeNotifier: exercises + sessions, used by all screens
    settings.dart             SharedPreferences-backed settings
    workout_controller.dart   one running workout: current set, logged reps, rest timer (end timestamp + clock injection)
    rest_alerts.dart          RestAlerts interface; NotificationRestAlerts schedules a local notification for rest end
  ui/                         screens (home, workout, finish, history, progress, settings) + widgets/common.dart
    analysis_sheet.dart       "Analyze history": period → share CSV (share_plus) + prompt to clipboard, or save CSV
```
- State management: `provider` + `ChangeNotifier`. No codegen.
- Storage: sqflite. Tables `exercises`, `sessions`, `exercise_results` (targets/actuals are stored as CSV strings of 7 ints).
  History rows keep `exercise_name`, so they stay readable after an exercise is renamed or deleted.
  v2 added `sessions.rpe/note` (optional, from the finish screen) and `exercise_results.set_seconds/rest_before_seconds`
  (CSV with empty entries for unknown; empty for v1 workouts). `test/repository_test.dart` checks the v1 → v2 upgrade.
- Timing: `set_seconds` = from "ready" (workout start or rest end) to logging the set; `rest_before_seconds` = rest actually
  taken (after ±15 s/skip). A rest that ends in background counts until `restEndsAt`, not until the app resumes.
- The rest timer depends on `restEndsAt`, not on counting ticks, so it stays correct in background. `tick()` is called on app resume.
- Rest sounds come from the app (`audioplayers`) on the **media** stream, not from notifications. The owner's phone
  runs in Do Not Disturb/silent, which mutes notification sounds. When 5 s of rest are left, `WorkoutController.tick()` calls
  `RestAlerts.countdownStarted` once. That plays `assets/sounds/countdown.wav`: beeps at 0–4 s and a long end beep at 5 s,
  seeked if less than 5 s is left. Playback takes transient audio focus, so other music ducks or pauses
  (the "Other music while beeping" setting). If countdown beeps are off, `end.wav` plays when rest ends.
  Regenerate the sounds with `python3 tool/generate_sounds.py`.
- A silent, vibrating notification (channel `rest_end_silent`) is scheduled for rest end as a fallback when the screen is off.
  It uses an exact alarm and falls back to inexact. Channel settings are fixed once a channel is created on a device, so
  change the channel id to change them. The old channels are deleted in `init()`.
- Ownership: `WorkoutScreen` creates the `WorkoutController`; when the workout finishes, `FinishScreen` takes ownership and disposes it.

## Commands
```bash
flutter pub get
flutter analyze                 # must be clean
flutter test                    # unit + widget tests (sqflite via sqflite_common_ffi in-memory)
flutter run                     # phone connected with USB debugging, or emulator
flutter build apk --release --split-per-abi   # phone APK: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb install -r build/app/outputs/flutter-apk/app-release.apk   # update the phone and KEEP data
# NOTE: `flutter install` uninstalls first and wipes the app's data – don't use it on the owner's phone.
```

## Conventions
- Keep the logic in `lib/logic` and `WorkoutController` free of Flutter UI so it can be unit tested. Add tests there for any rule change.
- Update `test/app_flow_test.dart` when the main workout flow changes. It drives Home → Workout → Finish → Save.
- Dark Material 3 theme with a green seed. Large touch targets on the workout screen.
- Never commit signing keys (`*.jks`, `key.properties`) or APKs. The release build currently uses the debug signing key, which is fine for personal sideloading.
- Android: package `com.cagrihakkoymaz.simple_strength_training`. Core library desugaring is required by flutter_local_notifications.
- CI (`.github/workflows/build.yml`) runs analyze, test, and the APK build on every push to `main` and uploads the arm64 APK as an artifact.

## Future work
- Garmin fenix 7 watch version: see [garmin_extension_feasability.md](garmin_extension_feasability.md) (feasibility only, not started).
