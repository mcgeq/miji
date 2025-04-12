// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           web_notification.dart
// Description:    About WebNotification
// Create   Date:  2025-04-12 10:57:24
// Last Modified:  2025-04-12 10:57:31
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

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
  // Add a private constructor
  WebNotification._();

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
      // Don't show past notifications on web? Or show immediately?
      // _showNotification(title, body); // Option: Show immediately
      print(
        "Attempted to schedule past notification on web: $title",
      ); // Option: Log it
      return;
    }

    // Cancel existing timer for this ID if any
    cancelNotification(id);

    _timers[id] = Timer(delay, () {
      _showNotification(title, body);
      _timers.remove(id); // Remove timer after showing
    });
  }

  static void cancelNotification(int id) {
    final timer = _timers.remove(id); // Remove and get timer
    timer?.cancel();
  }

  static void _showNotification(String title, String body) {
    if (_notificationPermission == 'granted') {
      try {
        final options = web.NotificationOptions(body: body);
        createNotification(title, options);
      } catch (e) {
        print("Error showing web notification: $e");
      }
    } else {
      print("Web notification permission not granted.");
    }
  }
}
