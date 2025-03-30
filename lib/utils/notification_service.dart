import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// 条件导入 dart:html，仅在 Web 平台使用
import 'package:mcge_pisces/utils/web_notification.dart'
    if (dart.library.io) 'package:mcge_pisces/stub/web_notification_stub.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) {
      // Web 平台：请求通知权限
      await WebNotification.requestPermission();
      return;
    }

    // 初始化时区
    tz.initializeTimeZones();

    // 设置 Android 初始化参数
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 设置 Windows 初始化参数
    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
          appName: 'Pisces Note',
          appUserModelId: 'com.example.pisces_note',
          guid: 'D926C4A2-5A7B-4F5A-8E3A-3F5B2C4D7E9F',
        );

    // 合并所有平台的初始化设置
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          windows: initializationSettingsWindows,
        );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (kIsWeb) {
      // Web 平台：使用 WebNotification 调度通知
      WebNotification.scheduleNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
      );
      return;
    }

    // Android 和 Windows 平台
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'todo_channel',
          'Todo Notifications',
          channelDescription: 'Notifications for Todo reminders',
          importance: Importance.max,
          priority: Priority.high,
        );

    // 为 Windows 提供必需参数
    const WindowsNotificationDetails windowsDetails =
        WindowsNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      windows: windowsDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelNotification(int id) async {
    if (kIsWeb) {
      WebNotification.cancelNotification(id);
      return;
    }
    await _notificationsPlugin.cancel(id);
  }
}
