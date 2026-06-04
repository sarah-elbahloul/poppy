import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

// ─────────────────────────────────────────────────────────────
//  POPPY — NotificationService
//  Location: lib/services/notification_service.dart
//
//  Handles initialisation, permission requests, and scheduling
//  of the daily writing reminder.
//
//  Call NotificationService.init() once from main() before
//  runApp().  Everything else is static.
// ─────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'poppy_reminders';
  static const _channelName = 'Writing Reminders';
  static const _channelDesc = 'Daily nudge to write in your diary.';
  static const _notifId     = 0;

  // ── Initialise ────────────────────────────────────────────

  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission:  false,   // we ask explicitly later
      requestBadgePermission:  false,
      requestSoundPermission:  false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create the Android notification channel (no-op on iOS / if exists)
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance:  Importance.defaultImportance,
      ),
    );
  }

  // ── Permission request ────────────────────────────────────

  /// Call this when the user first enables notifications in settings.
  /// Returns true if permission was granted (or was already granted).
  static Future<bool> requestPermission() async {
    // Android 13+
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true; // other platforms
  }

  // ── Schedule daily reminder ────────────────────────────────

  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await _plugin.cancel(_notifId); // cancel any existing

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year, now.month, now.day,
      time.hour, time.minute,
    );

    // If that time has already passed today, start from tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      _notifId,
      'Time to write 🌸',
      'A few words a day keeps the chaos away.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance:         Importance.defaultImportance,
          priority:           Priority.defaultPriority,
          icon:               '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Cancel ────────────────────────────────────────────────

  static Future<void> cancelReminders() async {
    await _plugin.cancel(_notifId);
  }
}