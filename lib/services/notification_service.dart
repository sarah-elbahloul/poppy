import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Manages local notifications for daily journal reminders.
///
/// **Why notifications stop working (and the fix):**
/// The most common failure is `tz.local` pointing to UTC instead of the
/// device's real timezone. This is because `tz.initializeTimeZones()` alone
/// does NOT set `tz.local` — you must also call `tz.setLocalLocation()`
/// with the device's IANA timezone name (e.g. "America/New_York").
/// We use the `flutter_timezone` package to get the correct name at runtime.
///
/// On Android you also need `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM`
/// in the manifest AND the `AlarmManager` exact-alarm permission granted by
/// the user (Settings → Apps → Special App Access → Alarms & reminders).
/// We request this via [requestPermission].
class NotificationService {
  NotificationService._();

  static final _notificationPlugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'poppy_reminders';
  static const _channelName = 'Writing Reminders';
  static const _channelDesc = 'Daily nudge to write in your diary.';
  static const _notifId = 0;

  // --- Initialization ---

  /// Configures the notification system and correctly initializes time zones.
  ///
  /// Must be called before any scheduling operations.
  static Future<void> init() async {
    // 1. Load the full IANA timezone database.
    tz.initializeTimeZones();
    // 2. Set tz.local to the device's actual timezone.
    //    Without this, all scheduled times are silently in UTC.
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier),);
    } catch (_) {
      // Fallback: keep UTC rather than crash.
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notificationPlugin.initialize(const InitializationSettings(android: android, iOS: ios),);

    await _notificationPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.defaultImportance,
      ),
    );
  }

  // --- Permissions ---

  /// Requests notification permissions from the user.
  ///
  /// On Android 13+ this requests POST_NOTIFICATIONS.
  /// On Android 12+ this also requests SCHEDULE_EXACT_ALARM when available.
  /// Returns true if all required permissions were granted.
  static Future<bool> requestPermission() async {
    final android = _notificationPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      // Request POST_NOTIFICATIONS (Android 13+).
      final notifGranted = await android.requestNotificationsPermission();
      if (notifGranted == false) return false;

      // Request exact alarm permission (Android 12+).
      // This is required for zonedSchedule to fire at the exact time.
      final exactGranted = await android.requestExactAlarmsPermission();
      // exactGranted is null on older APIs that don't need this permission.
      if (exactGranted == false) return false;

      return true;
    }

    final ios = _notificationPlugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  // --- Scheduling ---

  /// Schedules a recurring daily notification at the specified [time].
  ///
  /// Cancels any existing reminders before scheduling the new one.
  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await _notificationPlugin.cancel(_notifId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, start tomorrow.
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _notificationPlugin.zonedSchedule(
      _notifId,
      'Time to write 🌸',
      'A few words a day keeps the chaos away.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // exactAllowWhileIdle fires at the exact time even in battery-saver mode.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Disables and removes all active writing reminders.
  static Future<void> cancelReminders() async {
    await _notificationPlugin.cancel(_notifId);
  }
}