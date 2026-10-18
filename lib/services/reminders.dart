import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/models.dart';

/// Daily local notifications only. Background auto-play of recorded speech is
/// NOT implemented: tapping the notification opens the app for voice playback.
class ReminderService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    await _plugin.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: false,
          requestBadgePermission: false, requestSoundPermission: false),
    ));
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<bool> enableNotifications() async =>
      await _android?.requestNotificationsPermission() ?? true;

  Future<bool> enableExactAlarms() async {
    await initialize();
    return await _android?.requestExactAlarmsPermission() ?? false;
  }

  Future<bool> canUseExact() async =>
      await _android?.canScheduleExactNotifications() ?? false;

  Future<bool> notificationsEnabled() async =>
      await _android?.areNotificationsEnabled() ?? true;

  Future<void> cancel(Medication medication) async {
    await initialize();
    await _plugin.cancel(id: medication.notificationId);
  }

  Future<void> schedule(Medication medication) async {
    await initialize();
    await cancel(medication);
    if (!medication.active) return;
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day,
        medication.hour, medication.minute);
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1,
          medication.hour, medication.minute);
    }
    final mode = await canUseExact()
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    await _plugin.zonedSchedule(
      id: medication.notificationId,
      title: 'MedMitra • ${medication.name}',
      body: '${medication.doseAmount} ${medication.doseUnit} • ${medication.instructions}',
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'medmitra_medication_v1', 'Medicine reminders',
          channelDescription: 'Saved medication schedule notifications',
          importance: Importance.max, priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          playSound: true, visibility: NotificationVisibility.private,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: mode,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: medication.id,
    );
  }

  Future<void> rescheduleAll(List<Medication> medicines) async {
    for (final medication in medicines) {
      await schedule(medication);
    }
  }
}
