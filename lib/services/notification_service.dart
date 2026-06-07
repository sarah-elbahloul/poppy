import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Poppy — Notification Service
///
/// Handles initialization, permission requests, and scheduling of daily 
/// writing reminders using local notifications.
///
/// Call [NotificationService.init] once from `main()` before [runApp].
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'poppy_reminders';
  static const _channelName = 'Writing Reminders';
  static const _channelDesc = 'Daily nudge to write in your diary.';
  static const _notifId     = 0;

  // --- Initialisation ---

  /// Initializes the notification plugin and configures time zones.
  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission:  false,   // Asked explicitly later.
      requestBadgePermission:  false,
      requestSoundPermission:  false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create the Android notification channel.
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

  // --- Permission Request ---

  /// Requests notification permissions from the user.
  /// Returns true if permission was granted.
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

    return true; // Other platforms.
  }

  // --- Schedule Daily Reminder ---

  /// Schedules a recurring daily notification at the specified [time].
  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await _plugin.cancel(_notifId); // Cancel existing reminders.

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year, now.month, now.day,
      time.hour, time.minute,
    );

    // If the time has already passed today, schedule for tomorrow.
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
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // --- Cancellation ---

  /// Cancels all scheduled writing reminders.
  static Future<void> cancelReminders() async {
    await _plugin.cancel(_notifId);
  }
}
