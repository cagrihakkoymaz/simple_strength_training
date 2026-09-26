import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'settings.dart';

/// Seconds of audible countdown before rest ends.
const kCountdownSeconds = 5;

/// Alerts the user around the end of a rest period.
abstract class RestAlerts {
  /// Background fallback: scheduled system notification at rest end.
  Future<void> scheduleRestEnd(DateTime at, String body);
  Future<void> cancelRestEnd();

  /// Called once when [remaining] (≤ [kCountdownSeconds]) is left in the rest.
  void countdownStarted(Duration remaining);

  /// Called by the in-app timer when rest ends.
  void restEndedInApp();

  /// Rest skipped/extended or workout ended: silence any countdown audio.
  void stopSounds();
}

class NoopRestAlerts implements RestAlerts {
  const NoopRestAlerts();
  @override
  Future<void> scheduleRestEnd(DateTime at, String body) async {}
  @override
  Future<void> cancelRestEnd() async {}
  @override
  void countdownStarted(Duration remaining) {}
  @override
  void restEndedInApp() {}
  @override
  void stopSounds() {}
}

/// Beeps are played by the app on the **media** stream, so they are heard
/// whenever music is audible, even in silent / Do Not Disturb mode. While
/// beeping the app takes transient audio focus, so other apps (YouTube Music…)
/// lower their volume or pause, per [Settings.otherAudioMode].
///
/// A silent (vibrating) notification is also scheduled at rest end as a
/// fallback when the screen is off or the app is in background.
class NotificationRestAlerts implements RestAlerts {
  NotificationRestAlerts(this._settings);

  final Settings _settings;
  final _plugin = FlutterLocalNotificationsPlugin();
  final _player = AudioPlayer(playerId: 'rest_beeps');
  bool _ready = false;
  bool _countdownPlaying = false;

  static const _restNotificationId = 1;
  static final _countdownSound = AssetSource('sounds/countdown.wav');
  static final _endSound = AssetSource('sounds/end.wav');

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'rest_end_silent',
      'Rest finished',
      channelDescription: 'Vibrates when a rest period ends (the beeps come from the app)',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      category: AndroidNotificationCategory.alarm,
      timeoutAfter: 15000,
    ),
    iOS: DarwinNotificationDetails(presentSound: false, presentAlert: true),
  );

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      // Channels from v1.0 that played the (DND-muted) notification sound.
      for (final old in ['rest_end_sound', 'rest_end_vibrate']) {
        await android?.deleteNotificationChannel(channelId: old);
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSource(_countdownSound); // preload
    } catch (e) {
      debugPrint('Audio unavailable: $e');
    }
  }

  bool get _vibrate => _settings.restAlertMode != RestAlertMode.off;
  bool get _sound => _settings.restAlertMode == RestAlertMode.soundAndVibration;

  AudioContext get _audioContext {
    final pause = _settings.otherAudioMode == OtherAudioMode.pause;
    return AudioContext(
      android: AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.media,
        audioFocus: pause ? AndroidAudioFocus.gainTransient : AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: pause ? const {} : const {AVAudioSessionOptions.duckOthers},
      ),
    );
  }

  @override
  Future<void> scheduleRestEnd(DateTime at, String body) async {
    await cancelRestEnd();
    if (!_ready || !_vibrate) return;
    final when = tz.TZDateTime.from(at, tz.UTC);
    if (!when.isAfter(tz.TZDateTime.now(tz.UTC))) return;
    for (final scheduleMode in [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _plugin.zonedSchedule(
          id: _restNotificationId,
          scheduledDate: when,
          notificationDetails: _details,
          androidScheduleMode: scheduleMode,
          title: 'Rest is over 💪',
          body: body,
        );
        return;
      } catch (e) {
        // Exact alarms not permitted on this device: fall back to inexact.
        debugPrint('zonedSchedule($scheduleMode) failed: $e');
      }
    }
  }

  @override
  Future<void> cancelRestEnd() async {
    if (!_ready) return;
    await _plugin.cancel(id: _restNotificationId);
  }

  @override
  void countdownStarted(Duration remaining) {
    if (!_sound || !_settings.countdownBeeps) return;
    // countdown.wav ends its final beep at 5 s; start part-way in if less is left.
    final offset = const Duration(seconds: kCountdownSeconds) - remaining;
    _countdownPlaying = true;
    _play(_countdownSound, offset.isNegative ? Duration.zero : offset);
  }

  @override
  void restEndedInApp() {
    if (_vibrate) HapticFeedback.heavyImpact();
    // The countdown file already contains the end beep.
    if (_sound && !_countdownPlaying) _play(_endSound, Duration.zero);
    _countdownPlaying = false;
  }

  @override
  void stopSounds() {
    _countdownPlaying = false;
    _player.stop().catchError((Object e) => debugPrint('stop failed: $e'));
  }

  Future<void> _play(Source source, Duration position) async {
    try {
      await _player.stop();
      await _player.play(source, ctx: _audioContext, position: position);
    } catch (e) {
      debugPrint('Beep failed: $e');
    }
  }
}
