import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class AppNotificationService {
  AppNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const budgetAlertsChannelId = 'money_budget_alerts';
  static const budgetAlertsChannelName = '预算提醒';
  static const budgetAlertsChannelDescription = '预算接近阈值、超支和收入目标提醒';
  static const billRemindersChannelId = 'money_bill_reminders';
  static const billRemindersChannelName = '账单提醒';
  static const billRemindersChannelDescription = '账单、还款和周期事项到期提醒';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initializeFuture;

  Future<bool> showBudgetAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    return _showAndroidNotification(
      id: id,
      title: title,
      body: body,
      channelId: budgetAlertsChannelId,
      channelName: budgetAlertsChannelName,
      channelDescription: budgetAlertsChannelDescription,
      payload: payload,
    );
  }

  Future<bool> showBillReminder({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    return _showAndroidNotification(
      id: id,
      title: title,
      body: body,
      channelId: billRemindersChannelId,
      channelName: billRemindersChannelName,
      channelDescription: billRemindersChannelDescription,
      payload: payload,
    );
  }

  Future<bool> _showAndroidNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    String? payload,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final allowed = await ensureCanNotify();
    if (!allowed) {
      return false;
    }

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
    return true;
  }

  Future<bool> ensureCanNotify() async {
    await _ensureInitialized();
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    final status = await Permission.notification.status;
    if (status.isGranted) {
      return true;
    }
    final requested = await Permission.notification.request();
    return requested.isGranted;
  }

  Future<void> _ensureInitialized() {
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }
}
