import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

// ─────────────────────────────────────────────────────────────
//  POPPY — Notification Service
//  Location: lib/core/services/notification_service.dart
// ─────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();

  static final _notificationPlugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'poppy_reminders';
  static const _channelName = 'Writing Reminders';
  static const _channelDesc = 'Daily nudge to write in your diary.';
  static const _notifId = 0;

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier),);
    } catch (_) {}

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

  static Future<bool> requestPermission() async {
    final android = _notificationPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final notifGranted = await android.requestNotificationsPermission();
      if (notifGranted == false) return false;
      final exactGranted = await android.requestExactAlarmsPermission();
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminders() async {
    await _notificationPlugin.cancel(_notifId);
  }
}
