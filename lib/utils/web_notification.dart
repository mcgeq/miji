// web_notification.dart（仅 Web 平台使用）

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// 绑定全局 Notification 构造函数
@JS('Notification')
external web.Notification createNotification(
  String title, [
  web.NotificationOptions? options,
]);

/// 绑定 Notification.permission 静态属性
@JS('Notification.permission')
external String get _notificationPermission;

/// 绑定 Notification.requestPermission 静态方法
@JS('Notification.requestPermission')
external Future<String> _requestNotificationPermission();

class WebNotification {
  static final Map<int, Timer> _timers = {};

  static Future<void> requestPermission() async {
    if (_notificationPermission != 'granted') {
      await _requestNotificationPermission();
    }
  }

  static void scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) {
    final now = DateTime.now();
    final delay = scheduledDate.difference(now);

    if (delay.isNegative) {
      _showNotification(title, body);
      return;
    }

    _timers[id] = Timer(delay, () {
      _showNotification(title, body);
      _timers.remove(id);
    });
  }

  static void cancelNotification(int id) {
    final timer = _timers[id];
    timer?.cancel();
    _timers.remove(id);
  }

  static void _showNotification(String title, String body) {
    if (_notificationPermission == 'granted') {
      final options = web.NotificationOptions(body: body);
      createNotification(title, options);
    }
  }
}
