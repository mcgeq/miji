import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/notifications/app_notification_service.dart';
import 'package:miji/core/notifications/notification_tap_bus.dart';

/// 全局唯一的通知点击通道。
///
/// 必须是全局单例而不是 Autodispose：插件层的回调注册一次后长期有效，
/// 如果 bus 随着某个页面销毁而被 dispose，后续点击就没人接了。
final notificationTapBusProvider = Provider<NotificationTapBus>((ref) {
  final bus = NotificationTapBus();
  ref.onDispose(bus.close);
  return bus;
});

/// 通知服务。
///
/// 桌面端也返回实例：`AppNotificationService` 自身会在
/// `supportsNotifications == false` 时把所有操作降级成空操作，调用方不必
/// 到处写 `?.` 和平台判断。
final appNotificationServiceProvider = Provider<AppNotificationService>((ref) {
  return AppNotificationService(tapBus: ref.watch(notificationTapBusProvider));
});
