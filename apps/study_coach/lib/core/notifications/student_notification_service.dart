import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'student_reminder.dart';

class StudentNotificationService {
  StudentNotificationService(this._plugin);

  static const _scheduledIdsKey = 'student_notification_scheduled_ids';
  static const _androidChannelId = 'student_reminders';
  static const _androidChannelName = 'Student reminders';
  static const _androidChannelDescription =
      'Study sessions, deadlines, missed sessions, exams, and daily plans.';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _pluginUnavailable = false;

  Future<void> initialize() async {
    if (_initialized || _pluginUnavailable) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_pillar_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    try {
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } on MissingPluginException {
      _pluginUnavailable = true;
    }
  }

  Future<void> reconcileReminders(List<StudentReminder> reminders) async {
    await initialize();
    if (_pluginUnavailable) {
      await _storeIds(const <int>{});
      return;
    }
    final granted = await _requestPermissions();
    if (!granted) {
      await clearScheduledStudentReminders();
      return;
    }

    final currentIds = await _storedIds();
    final nextIds = reminders.map((r) => r.id).toSet();
    final staleIds = currentIds.difference(nextIds);

    final scheduledIds = <int>{};
    try {
      for (final id in staleIds) {
        await _plugin.cancel(id: id);
      }
      for (final reminder in reminders) {
        try {
          await _plugin.cancel(id: reminder.id);
          await _plugin.zonedSchedule(
            id: reminder.id,
            title: reminder.title,
            body: reminder.body,
            scheduledDate: reminder.fireAt,
            notificationDetails: _notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: reminder.key,
            matchDateTimeComponents:
                reminder.repeatsDaily ? DateTimeComponents.time : null,
          );
          scheduledIds.add(reminder.id);
        } on Object catch (e, st) {
          if (kDebugMode) {
            debugPrint(
              'StudentNotificationService: skipped reminder ${reminder.key}: $e',
            );
            debugPrintStack(stackTrace: st);
          }
        }
      }
    } on MissingPluginException {
      _pluginUnavailable = true;
      await _storeIds(const <int>{});
      return;
    }

    await _storeIds(scheduledIds);
  }

  Future<void> clearScheduledStudentReminders() async {
    await initialize();
    if (_pluginUnavailable) {
      await _storeIds(const <int>{});
      return;
    }
    final ids = await _storedIds();
    try {
      for (final id in ids) {
        await _plugin.cancel(id: id);
      }
    } on MissingPluginException {
      _pluginUnavailable = true;
    }
    await _storeIds(const <int>{});
  }

  Future<bool> _requestPermissions() async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final androidGranted =
          await androidPlugin?.requestNotificationsPermission();
      if (androidGranted != null) return androidGranted;

      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final iosGranted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (iosGranted != null) return iosGranted;

      final macPlugin = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final macGranted = await macPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return macGranted ?? true;
    } on MissingPluginException {
      _pluginUnavailable = true;
      return false;
    }
  }

  Future<Set<int>> _storedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_scheduledIdsKey) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  Future<void> _storeIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scheduledIdsKey,
      ids.map((id) => id.toString()).toList()..sort(),
    );
  }

  static const _notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: _androidChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );
}
