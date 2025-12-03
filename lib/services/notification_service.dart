import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Manages daily reminder notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> initialize() async {
    if (_initialised) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTapped,
    );

    _initialised = true;
  }

  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Schedules a daily notification at the given time.
  Future<void> scheduleDailyNotification({int hour = 22, int minute = 0}) async {
    await initialize();

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('Notification permission denied');
      return;
    }

    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // If we're past today's slot, schedule for tomorrow.
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    debugPrint('Scheduling notification for: $scheduled');

    await _plugin.zonedSchedule(
      0,
      'Time to Record',
      'Please complete your daily voice recording',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_recording',
          'Daily Recording Reminder',
          channelDescription: 'Daily reminder to complete voice recording',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint('Daily notification scheduled successfully');
  }

  void _onTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  /// Quick test helper to fire a notification immediately.
  Future<void> showImmediateNotification() async {
    await initialize();

    await _plugin.show(
      1,
      'Test Notification',
      'This is a test notification from NeuroLens',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test Notifications',
          channelDescription: 'Test notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}