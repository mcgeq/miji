import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:miji/core/notifications/notification_tap_bus.dart';

/// 通知点击 payload 的前缀约定。
///
/// 现有 payload 有三种形态：账单提醒 / 预算提醒塞的是实体 id，打卡模块塞的是
/// planId。为了避免路由层靠「猜格式」区分来源，新增的记账通知统一带前缀。
abstract final class NotificationPayloads {
  /// 记账提醒（账单 / 还款 / 分期 / 预算），跳转到记账模块的提醒面板。
  static const moneyReminder = 'miji://money/reminders';

  /// 预算超支 / 达阈值提醒，跳转到预算面板（它没有可结清的动作）。
  static const moneyBudgets = 'miji://money/budgets';

  /// 每日记账提醒，跳转到记账并直接打开记一笔。
  static const moneyDailyLog = 'miji://money/log';
}

class AppNotificationService {
  AppNotificationService({FlutterLocalNotificationsPlugin? plugin, this.tapBus})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const budgetAlertsChannelId = 'money_budget_alerts';
  static const budgetAlertsChannelName = '预算提醒';
  static const budgetAlertsChannelDescription = '预算接近阈值、超支和收入目标提醒';
  static const billRemindersChannelId = 'money_bill_reminders';
  static const billRemindersChannelName = '账单提醒';
  static const billRemindersChannelDescription = '账单、还款和周期事项到期提醒';
  static const dailyLogChannelId = 'money_daily_log';
  static const dailyLogChannelName = '记账提醒';
  static const dailyLogChannelDescription = '每天固定时间提醒记录当天收支';
  static const checkinRemindersChannelId = 'checkin_reminders';
  static const checkinRemindersChannelName = '打卡提醒';
  static const checkinRemindersChannelDescription = '每日计划和纪念日打卡提醒';

  /// 通知点击的出口。为 null 时点击只做冷启动，不导航。
  final NotificationTapBus? tapBus;

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initializeFuture;

  /// 本地通知只在移动平台可用。
  ///
  /// 桌面端（Windows / macOS / Linux）没有可靠的本地通知通道，
  /// 保留这个判断而不是让调用方各写一遍平台分支。
  bool get supportsNotifications =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

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

  /// 预约一条本地通知。
  ///
  /// [matchDateTimeComponents] 传 `DateTimeComponents.time` 表示每天这个时间
  /// 重复，传 null 表示一次性。
  Future<bool> schedule({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
  }) async {
    if (!supportsNotifications) {
      return false;
    }
    final allowed = await ensureCanNotify();
    if (!allowed) {
      debugPrint('[notify] 通知权限未授予，跳过调度：channel=$channelId');
      return false;
    }

    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _details(
          channelId: channelId,
          channelName: channelName,
          channelDescription: channelDescription,
          importance: importance,
          priority: priority,
        ),
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (error, stackTrace) {
      debugPrint('[notify] 通知调度失败: $error\n$stackTrace');
      return false;
    }
    return true;
  }

  /// 取消一条预约通知。已弹出的通知不受影响。
  Future<void> cancel(int id) async {
    if (!supportsNotifications) {
      return;
    }
    await _ensureInitialized();
    try {
      await _plugin.cancel(id: id);
    } catch (error, stackTrace) {
      debugPrint('[notify] 取消通知失败 id=$id: $error\n$stackTrace');
    }
  }

  /// 批量取消。调度器每轮同步都先清掉上一轮的预约，再重新排布。
  Future<void> cancelAll(Iterable<int> ids) async {
    if (!supportsNotifications || ids.isEmpty) {
      return;
    }
    await _ensureInitialized();
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (error, stackTrace) {
        debugPrint('[notify] 取消通知失败 id=$id: $error\n$stackTrace');
      }
    }
  }

  /// 取消本插件排的所有通知。
  Future<void> cancelEverything() async {
    if (!supportsNotifications) {
      return;
    }
    await _ensureInitialized();
    try {
      await _plugin.cancelAll();
    } catch (error, stackTrace) {
      debugPrint('[notify] 取消全部通知失败: $error\n$stackTrace');
    }
  }

  /// 当前仍挂在系统上的预约通知（用于排查"该推没推"）。
  Future<List<PendingNotificationRequest>> pendingNotifications() async {
    if (!supportsNotifications) {
      return const <PendingNotificationRequest>[];
    }
    await _ensureInitialized();
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return const <PendingNotificationRequest>[];
    }
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
    if (!supportsNotifications) {
      return false;
    }
    final allowed = await ensureCanNotify();
    if (!allowed) {
      debugPrint('[notify] 通知权限未授予，跳过：channel=$channelId');
      return false;
    }

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _details(
          channelId: channelId,
          channelName: channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        payload: payload,
      );
    } catch (error, stackTrace) {
      debugPrint('[notify] 通知发送失败: $error\n$stackTrace');
      return false;
    }
    return true;
  }

  NotificationDetails _details({
    required String channelId,
    required String channelName,
    required String channelDescription,
    required Importance importance,
    required Priority priority,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: importance,
        priority: priority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  Future<bool> ensureCanNotify() async {
    await _ensureInitialized();
    if (!supportsNotifications) {
      return false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // iOS 的权限由初始化时的 DarwinInitializationSettings 请求，
      // permission_handler 在 iOS 上没有 notification 权限的对应实现。
      return true;
    }

    final status = await Permission.notification.status;
    if (status.isGranted) {
      return true;
    }
    final requested = await Permission.notification.request();
    return requested.isGranted;
  }

  /// 调度每日打卡提醒。返回通知 ID，失败返回 null。
  Future<int?> scheduleDailyCheckinReminder({
    required String planId,
    required String planName,
    required String timeString,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;

    final allowed = await ensureCanNotify();
    if (!allowed) return null;

    final parts = timeString.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    final notificationId = planId.hashCode.abs() % 100000;
    await _plugin.cancel(id: notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: notificationId,
      title: '⏰ $planName',
      body: '该打卡啦！',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          checkinRemindersChannelId,
          checkinRemindersChannelName,
          channelDescription: checkinRemindersChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: planId,
    );
    return notificationId;
  }

  /// 取消指定计划的提醒。
  Future<void> cancelCheckinReminder(String planId) async {
    final notificationId = planId.hashCode.abs() % 100000;
    await _plugin.cancel(id: notificationId);
  }

  /// 调度纪念日提醒（每年重复，可提前 N 天）。
  Future<int?> scheduleAnniversaryReminder({
    required String planId,
    required String planName,
    required int month,
    required int day,
    String timeString = '09:00',
    int daysBefore = 0,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    final allowed = await ensureCanNotify();
    if (!allowed) return null;

    final parts = timeString.split(':');
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final notificationId = planId.hashCode.abs() % 100000;
    await _plugin.cancel(id: notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      month,
      day,
      hour,
      minute,
    ).subtract(Duration(days: daysBefore));

    if (scheduled.isBefore(now) || scheduled == now) {
      scheduled = tz.TZDateTime(
        tz.local,
        now.year + 1,
        month,
        day,
        hour,
        minute,
      ).subtract(Duration(days: daysBefore));
    }

    await _plugin.zonedSchedule(
      id: notificationId,
      title: '🎉 $planName',
      body: daysBefore > 0
          ? '还有 $daysBefore 天就是 $planName 啦！'
          : '今天是 $planName！',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          checkinRemindersChannelId,
          checkinRemindersChannelName,
          channelDescription: checkinRemindersChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: planId,
    );
    return notificationId;
  }

  /// 调度间隔提醒（每 N 小时重复）。
  Future<int?> scheduleIntervalReminder({
    required String planId,
    required String planName,
    required int intervalHours,
    String timeString = '08:00',
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    final allowed = await ensureCanNotify();
    if (!allowed) return null;

    final parts = timeString.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    final notificationId = planId.hashCode.abs() % 100000;
    await _plugin.cancel(id: notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(Duration(hours: intervalHours));
    }

    await _plugin.zonedSchedule(
      id: notificationId,
      title: '⏰ $planName',
      body: '该打卡啦！',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          checkinRemindersChannelId,
          checkinRemindersChannelName,
          channelDescription: checkinRemindersChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: planId,
    );
    return notificationId;
  }

  /// 调度每周打卡报告（周一推送）。
  Future<void> scheduleWeeklyReport({
    required int completedCheckins,
    required double completionRate,
    required String topCategory,
    int hour = 9,
    int minute = 0,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final allowed = await ensureCanNotify();
    if (!allowed) return;

    const reportId = 9999;
    await _plugin.cancel(id: reportId);

    final now = tz.TZDateTime.now(tz.local);
    var monday = now;
    while (monday.weekday != DateTime.monday) {
      monday = monday.add(const Duration(days: 1));
    }
    var scheduled = tz.TZDateTime(
      tz.local,
      monday.year,
      monday.month,
      monday.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }

    await _plugin.zonedSchedule(
      id: reportId,
      title: '📊 本周打卡报告',
      body:
          '完成 $completedCheckins 次 · 完成率 ${(completionRate * 100).toInt()}% · 最多: $topCategory',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          checkinRemindersChannelId,
          checkinRemindersChannelName,
          channelDescription: checkinRemindersChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weekly_report',
    );
  }

  /// 调度每日记账提醒汇总（兜底）：当有待处理提醒时，每天固定时间
  /// 推一条通知提醒用户打开 App 查看；pendingCount 为 0 时取消。
  /// 解决"用户当天完全不打开 App 就收不到任何提醒"的缺口。
  Future<void> scheduleDailyMoneyReminderDigest({
    required int pendingCount,
    int hour = 20,
    int minute = 0,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await _ensureInitialized();

    const digestId = 88001;
    await _plugin.cancel(id: digestId);

    if (pendingCount <= 0) {
      return;
    }
    final allowed = await ensureCanNotify();
    if (!allowed) {
      return;
    }

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

    await _plugin.zonedSchedule(
      id: digestId,
      title: '📌 今日提醒',
      body: '你有 $pendingCount 条账单/预算提醒待查看，打开米记处理。',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          billRemindersChannelId,
          billRemindersChannelName,
          channelDescription: billRemindersChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'money_daily_digest',
    );
  }

  Future<void> _ensureInitialized() {
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    if (!supportsNotifications) {
      return;
    }
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: const DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: false,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    await _emitLaunchPayload();
  }

  /// 从「通知栏点击 → 冷启动」进来的场景。
  ///
  /// 这条路径不经过 `onDidReceiveNotificationResponse`（进程是被通知拉起来的，
  /// 回调注册得太晚），必须显式读一次 launch details，否则点击通知只会打开首页。
  Future<void> _emitLaunchPayload() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      final response = details?.notificationResponse;
      if (response == null) {
        return;
      }
      _onNotificationResponse(response);
    } catch (_) {
      // 拿不到 launch details 不影响通知本身。
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    // 只对带 `miji://` 前缀的 payload 做导航：账单 / 预算提醒历史上塞的是实体 id，
    // 直接拿去当路由会跳错地方。
    if (!payload.startsWith('miji://')) {
      return;
    }
    tapBus?.emit(payload);
  }
}
