import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'settings.dart';

/// Alerts the user when a rest period ends.
abstract class RestAlerts {
  Future<void> scheduleRestEnd(DateTime at, String body);
  Future<void> cancelRestEnd();

  /// Called by the in-app timer when rest ends while the app is visible.
  void restEndedInApp();
}

class NoopRestAlerts implements RestAlerts {
  const NoopRestAlerts();
  @override
  Future<void> scheduleRestEnd(DateTime at, String body) async {}
  @override
  Future<void> cancelRestEnd() async {}
  @override
  void restEndedInApp() {}
}

/// Schedules a local notification for the end of every rest, so the phone
/// beeps/vibrates even when the screen is off or the app is in background.
class NotificationRestAlerts implements RestAlerts {
  NotificationRestAlerts(this._settings);

  final Settings _settings;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _restNotificationId = 1;

  static const _soundDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'rest_end_sound',
      'Rest finished (sound)',
      channelDescription: 'Alert when a rest period ends',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      timeoutAfter: 15000,
    ),
    iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
  );

  static const _vibrateDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'rest_end_vibrate',
      'Rest finished (vibration)',
      channelDescription: 'Silent vibrating alert when a rest period ends',
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
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  @override
  Future<void> scheduleRestEnd(DateTime at, String body) async {
    await cancelRestEnd();
    final mode = _settings.restAlertMode;
    if (!_ready || mode == RestAlertMode.off) return;
    final when = tz.TZDateTime.from(at, tz.UTC);
    if (!when.isAfter(tz.TZDateTime.now(tz.UTC))) return;
    final details = mode == RestAlertMode.soundAndVibration ? _soundDetails : _vibrateDetails;
    for (final scheduleMode in [
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _plugin.zonedSchedule(
          id: _restNotificationId,
          scheduledDate: when,
          notificationDetails: details,
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
  void restEndedInApp() {
    if (_settings.restAlertMode != RestAlertMode.off) {
      HapticFeedback.heavyImpact();
    }
  }
}
