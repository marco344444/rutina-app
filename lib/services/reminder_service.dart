import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/reminder_settings.dart';

class ReminderService {
  ReminderService._();

  static final instance = ReminderService._();
  final _notifications = FlutterLocalNotificationsPlugin();
  static const reminderId = 1001;
  static const testNotificationId = 1002;
  static const dailyChannelId = 'daily_routine_reminder';
  static const testChannelId = 'test_routine_reminder';
  bool _initialized = false;

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (!_initialized) await initialize();
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final alreadyEnabled = await android?.areNotificationsEnabled();
    final androidGranted = alreadyEnabled == true
        ? true
        : await android?.requestNotificationsPermission();
    final exactGranted = await android?.requestExactAlarmsPermission() ?? true;
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: false,
    );
    return (androidGranted ?? iosGranted ?? true) && exactGranted;
  }

  Future<bool> schedule(ReminderSettings settings) async {
    if (!_initialized) await initialize();
    await _notifications.cancel(reminderId);
    if (!settings.enabled) return true;
    await _createChannel(dailyChannelId, 'Recordatorios de Rutina');
    await _notifications.zonedSchedule(
      reminderId,
      'Rutina',
      'Recuerda registrar tus hábitos y tu peso de hoy.',
      _nextTime(settings.hour, settings.minute),
      _details(dailyChannelId, 'Recordatorios de Rutina'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    final pending = await _notifications.pendingNotificationRequests();
    return pending.any((notification) => notification.id == reminderId);
  }

  Future<bool> scheduleTestNotification() async {
    if (!_initialized) await initialize();
    await _createChannel(testChannelId, 'Pruebas de Rutina');
    await _notifications.cancel(testNotificationId);
    await _notifications.zonedSchedule(
      testNotificationId,
      'Rutina',
      'Notificación de prueba funcionando correctamente.',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
      _details(testChannelId, 'Pruebas de Rutina'),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    final pending = await _notifications.pendingNotificationRequests();
    return pending.any((notification) => notification.id == testNotificationId);
  }

  Future<void> _createChannel([
    String channelId = dailyChannelId,
    String channelName = 'Recordatorios de Rutina',
  ]) async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        dailyChannelId,
        'Recordatorios de Rutina',
        description: 'Recordatorio para registrar tu día',
        importance: Importance.defaultImportance,
        playSound: false,
      ),
    );
    if (channelId != dailyChannelId) {
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          channelId,
          channelName,
          description: 'Notificación temporal de prueba',
          importance: Importance.defaultImportance,
          playSound: false,
        ),
      );
    }
  }

  NotificationDetails _details(String channelId, String channelName) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Recordatorio para registrar tu día',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          playSound: false,
          enableVibration: false,
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      );

  tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
