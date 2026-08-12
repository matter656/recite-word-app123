import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 每日学习提醒（本地通知）。
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _reminderId = 1001;

  static Future<void> init() async {
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    // Android 13+ 需要运行时通知权限
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// 调度每日提醒；先取消旧提醒再排新的（保证时间更新生效）。
  static Future<void> scheduleDaily(TimeOfDay time) async {
    await _plugin.cancel(id: _reminderId);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: _reminderId,
      title: '背单词',
      body: '今天的单词还没背完，来打卡吧！',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          '每日提醒',
          channelDescription: '每天固定时间提醒背单词',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancel() async {
    await _plugin.cancel(id: _reminderId);
  }
}
