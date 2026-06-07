import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Manages local notifications for daily journal reminders.
///
/// Responsibilities:
/// - Initializing the notification plugin and configuring time zones.
/// - Handling platform-specific permissions (Android 13+ and iOS).
/// - Scheduling and canceling recurring daily writing prompts.
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'poppy_reminders';
  static const _channelName = 'Writing Reminders';
  static const _channelDesc = 'Daily nudge to write in your diary.';
  static const _notifId = 0;

  // --- Initialization ---

  /// Configures the notification system and initializes time zone data.
  static Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
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
  /// Returns true if permissions were granted.
  static Future<bool> requestPermission() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
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

  /// Schedules a daily notification at the specified [time].
  ///
  /// Cancels any existing reminders before scheduling the new one.
  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await _plugin.cancel(_notifId);

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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Disables and removes all active writing reminders.
  static Future<void> cancelReminders() async {
    await _plugin.cancel(_notifId);
  }
}
