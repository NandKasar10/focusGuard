import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open notification');

    const initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Notification init exception: $e');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'focusguard_channel',
      'FocusGuard Alerts',
      channelDescription: 'Notifications for limits, reminders, and daily summaries',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Could not display native notification: $e');
    }
  }

  /// Schedules a study reminder after N minutes (e.g. 40 min)
  Future<void> scheduleStudyReminder({
    required int id,
    required int delayMinutes,
    required String message,
  }) async {
    // In Flutter, if platform supports timed notifications or timer-based fallback
    Future.delayed(Duration(minutes: delayMinutes), () {
      showNotification(
        id: id,
        title: 'FocusGuard Reminder ⏰',
        body: message,
      );
    });
  }
}
