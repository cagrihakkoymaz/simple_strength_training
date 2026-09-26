# Simple Strength Training

A small offline Flutter app for the **Goliaz Strength Training** program:

1. Test your max reps for an exercise (pull-ups, push-ups, squats, dips…).
2. Every day, do the 7 sets for that max from the table ([docs/program_image.jpeg](docs/program_image.jpeg)) with rest between them.
3. If all 7 sets are **unbroken**, move to the next group tomorrow. If a set is **broken**, repeat the group.

## Features
- Starts with Pull-ups (group 11), Push-ups (20), and Squats (30). You can add, edit, or hide exercises.
- **Straight sets** or **Circuit** mode, chosen for each workout.
- Adjustable rest (between sets/rounds and between exercises) with a big countdown, ±15 s, and Skip.
- Audible countdown for the last 5 seconds of rest, played at media volume so it works in silent/Do Not Disturb.
  While it beeps, YouTube Music or Spotify is lowered or paused (your choice).
- One tap for a successful set. *Failed* lets you enter the reps you actually did. You can tap any logged set to correct it.
- After a workout you choose **Next group** or **Stay**. The app preselects based on the result.
- History with dates, groups, and every set, plus progress charts and training-day counts.
- JSON backup export and import.
- The phone stays awake during a workout.

## Install on an Android phone
**From GitHub:** open the repo's *Actions* tab, pick the latest successful *Build* run, and download
`strength-training-apk`. Unzip it and open the `.apk` on the phone (allow "install unknown apps").

**From a computer (USB debugging on):**
```bash
flutter build apk --release --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk   # -r keeps your data
```
Avoid `flutter install`. It uninstalls the app first, which deletes your workout history.

## Develop
```bash
flutter pub get
flutter analyze
flutter test
flutter run
```
See [CLAUDE.md](CLAUDE.md) for the architecture and the program rules.
