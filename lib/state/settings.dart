import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/workout_plan.dart';

enum RestAlertMode {
  soundAndVibration('Sound + vibration'),
  vibration('Vibration only'),
  off('Off');

  const RestAlertMode(this.label);
  final String label;
}

class Settings extends ChangeNotifier {
  Settings(this._prefs);

  final SharedPreferences _prefs;

  static const _kSetRest = 'set_rest_seconds';
  static const _kExerciseRest = 'exercise_rest_seconds';
  static const _kMode = 'last_mode';
  static const _kAlert = 'rest_alert_mode';

  /// Rest after each set (straight) or after each round (circuit).
  int get setRestSeconds => _prefs.getInt(_kSetRest) ?? 60;

  /// Rest between exercises inside a circuit round.
  int get exerciseRestSeconds => _prefs.getInt(_kExerciseRest) ?? 0;

  WorkoutMode get lastMode => WorkoutMode.fromName(_prefs.getString(_kMode));

  RestAlertMode get restAlertMode => RestAlertMode.values.firstWhere(
    (m) => m.name == _prefs.getString(_kAlert),
    orElse: () => RestAlertMode.soundAndVibration,
  );

  Future<void> setSetRestSeconds(int v) => _setInt(_kSetRest, v);
  Future<void> setExerciseRestSeconds(int v) => _setInt(_kExerciseRest, v);

  Future<void> setLastMode(WorkoutMode m) async {
    await _prefs.setString(_kMode, m.name);
    notifyListeners();
  }

  Future<void> setRestAlertMode(RestAlertMode m) async {
    await _prefs.setString(_kAlert, m.name);
    notifyListeners();
  }

  Future<void> _setInt(String key, int v) async {
    await _prefs.setInt(key, v < 0 ? 0 : v);
    notifyListeners();
  }
}
