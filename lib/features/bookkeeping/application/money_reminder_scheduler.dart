import 'dart:math' as math;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:miji/core/notifications/app_notification_service.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/application/money_reminder_settings.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';

/// 把「提醒中心的待处理项」翻译成系统级预约通知。
///
/// 为什么数据源是提醒中心而不是 `money_bill_reminders` 表：
/// 提醒中心已经聚合了预算 / 信用卡账单 / 分期 / 周期支出 / 账单提醒五种来源，
/// 并且已经按完成、忽略、延后状态过滤过——这是唯一正确的「还该不该打扰用户」
/// 口径。直接用提醒表会踩到它自身 `status` 恒为 pending 的坑，用户早处理完的
/// 账单依然天天推。
///
/// 为什么需要它：`scanAndNotify` 那套只有在 App 前台时才扫一次，不打开 App
/// 就收不到任何提醒。这里负责的是「不看 App 也会响」的那一半。
class MoneyReminderScheduler {
  MoneyReminderScheduler({required this.notificationService, this.now});

  final AppNotificationService notificationService;
  final DateTime Function()? now;

  /// 系统能稳定持有的预约上限。
  ///
  /// Android 的 AlarmManager 对每个应用有约 500 个闹钟的硬限制，且记账预约
  /// 只是「提醒」这一层，超出的部分交给每日汇总兜底，不做无意义的堆叠。
  static const maxScheduledReminders = 60;

  /// 每日记账提醒的固定通知 id。
  static const dailyLogNotificationId = 88002;

  static String _idsKeyFor(String userId) =>
      'money_scheduled_notification_ids_$userId';

  /// 重新排布该用户的全部记账类通知。
  ///
  /// 幂等：先取消上一轮排过的 id，再按当前待处理列表重排。这样处理掉、
  /// 延后、删除的提醒不会留下僵尸预约。
  Future<void> sync({
    required String userId,
    required List<MoneyReminderCenterItem> pending,
    required MoneyReminderSettings settings,
    required bool hasTransactionToday,
  }) async {
    if (!notificationService.supportsNotifications) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final idsKey = _idsKeyFor(userId);
    await _cancelPreviouslyScheduled(prefs, idsKey);

    // 总开关关闭：清干净就走，不再排任何东西。
    if (!settings.enabled) {
      await notificationService.cancel(dailyLogNotificationId);
      // pendingCount 传 0 的语义就是「取消这条汇总」。
      await notificationService.scheduleDailyMoneyReminderDigest(
        pendingCount: 0,
      );
      await prefs.remove(idsKey);
      return;
    }

    final today = _dateOnly((now ?? DateTime.now)());
    final ordered = _orderedPending(pending, today);
    final scheduledIds = <int>[];

    for (final item in ordered.take(maxScheduledReminders)) {
      final plan = _planFor(item, today, settings);
      if (plan == null) {
        continue;
      }
      final id = _notificationId(userId, item.itemKey);
      final shown = await notificationService.schedule(
        id: id,
        title: plan.title,
        body: plan.body,
        channelId: AppNotificationService.billRemindersChannelId,
        channelName: AppNotificationService.billRemindersChannelName,
        channelDescription:
            AppNotificationService.billRemindersChannelDescription,
        scheduledDate: plan.scheduledDate,
        payload: plan.payload,
        matchDateTimeComponents: plan.daily ? DateTimeComponents.time : null,
        importance: plan.daily ? Importance.defaultImportance : Importance.high,
        priority: plan.daily ? Priority.defaultPriority : Priority.high,
      );
      if (shown) {
        scheduledIds.add(id);
      }
    }

    await prefs.setString(idsKey, scheduledIds.join(','));

    // 兜底汇总：当天有待处理项时每天推一次「你有 N 条待查看」。
    if (settings.dailyDigestEnabled && ordered.isNotEmpty) {
      await notificationService.scheduleDailyMoneyReminderDigest(
        pendingCount: ordered.length,
        hour: settings.digestHour,
        minute: settings.digestMinute,
      );
    } else {
      await notificationService.scheduleDailyMoneyReminderDigest(
        pendingCount: 0,
      );
    }

    await _syncDailyLogReminder(
      settings: settings,
      hasTransactionToday: hasTransactionToday,
    );
  }

  Future<void> _cancelPreviouslyScheduled(
    SharedPreferences prefs,
    String idsKey,
  ) async {
    final raw = prefs.getString(idsKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    final ids = <int>[
      for (final part in raw.split(','))
        if (int.tryParse(part.trim()) != null) int.parse(part.trim()),
    ];
    await notificationService.cancelAll(ids);
  }

  /// 逾期 / 更紧急的排前面，超上限时优先保留这些。
  List<MoneyReminderCenterItem> _orderedPending(
    List<MoneyReminderCenterItem> pending,
    DateTime today,
  ) {
    final items = [...pending];
    items.sort((a, b) => a.comparePriorityTo(b, today: today));
    return items;
  }

  _MoneyReminderPlan? _planFor(
    MoneyReminderCenterItem item,
    DateTime today,
    MoneyReminderSettings settings,
  ) {
    final due = _dateOnly(item.dueDate);
    // 预算超支没有「到期日」语义，它一出现就该被看见。
    final visibleFrom = item.isBudgetExceeded
        ? due
        : due.subtract(Duration(days: item.remindBeforeDays));

    final amountText = formatMoneyMinor(item.amountMinor, item.currencyCode);
    final dayDelta = due.difference(today).inDays;
    final dueText = switch (dayDelta) {
      0 => '今天到期',
      > 0 => '$dayDelta 天后到期',
      _ => '已逾期 ${-dayDelta} 天',
    };
    final title = item.isBudgetExceeded ? '预算提醒' : '账单提醒';
    final body = '${item.title} $dueText，金额 $amountText。';
    final payload = item.isBudgetExceeded
        ? NotificationPayloads.moneyBudgets
        : NotificationPayloads.moneyReminder;

    final scheduledDate = _nextNotifyTime(
      today: today,
      at: visibleFrom,
      hour: settings.notifyHour,
      minute: settings.notifyMinute,
    );

    // 还不到提醒窗口：排一条一次性的精确提醒（提前 remindBeforeDays 天）。
    if (today.isBefore(visibleFrom)) {
      final target = tz.TZDateTime(
        tz.local,
        visibleFrom.year,
        visibleFrom.month,
        visibleFrom.day,
        settings.notifyHour,
        settings.notifyMinute,
      );
      return _MoneyReminderPlan(
        title: title,
        body: body,
        scheduledDate: target,
        payload: payload,
        daily: false,
      );
    }

    // 已进入窗口或已逾期：每天这个时间复推，直到用户处理掉
    // （处理会让它从待处理列表消失，下一轮同步即取消）。
    return _MoneyReminderPlan(
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
      daily: true,
    );
  }

  tz.TZDateTime _nextNotifyTime({
    required DateTime today,
    required DateTime at,
    required int hour,
    required int minute,
  }) {
    final anchor = today.isAfter(at) ? today : at;
    return tz.TZDateTime(
      tz.local,
      anchor.year,
      anchor.month,
      anchor.day,
      hour,
      minute,
    );
  }

  /// 每日记账提醒。
  ///
  /// 做成「每次同步时重新布防的一次性提醒」而不是每日重复：重复通知无法在
  /// 触发时判断"今天已经记过账了"，对已经记完的人是无谓打扰。这里在布防的
  /// 那一刻就检查当天有无流水，有就不排。
  Future<void> _syncDailyLogReminder({
    required MoneyReminderSettings settings,
    required bool hasTransactionToday,
  }) async {
    await notificationService.cancel(dailyLogNotificationId);
    if (!settings.dailyLogReminderEnabled || hasTransactionToday) {
      return;
    }

    final current = (now ?? DateTime.now)();
    var target = tz.TZDateTime(
      tz.local,
      current.year,
      current.month,
      current.day,
      settings.logReminderHour,
      settings.logReminderMinute,
    );
    if (!target.isAfter(tz.TZDateTime.from(current, tz.local))) {
      // 今天这个点已经过了，就等明天同一时间（下次打开 App 时会重新判断）。
      target = target.add(const Duration(days: 1));
    }

    await notificationService.schedule(
      id: dailyLogNotificationId,
      title: '今天还没记账',
      body: '花两分钟记一笔，账本才不会月底突然失真。',
      channelId: AppNotificationService.dailyLogChannelId,
      channelName: AppNotificationService.dailyLogChannelName,
      channelDescription: AppNotificationService.dailyLogChannelDescription,
      scheduledDate: target,
      payload: NotificationPayloads.moneyDailyLog,
    );
  }

  /// 预约 id 落在 [700000000, 701000000) 这一段。
  ///
  /// 预算 / 账单提醒的 id 用的是另一套 hash 且覆盖整个 int 正区间，给它一个
  /// 独立号段能把两套 id 撞车的概率压到可忽略。
  int _notificationId(String userId, String itemKey) {
    var value = 41;
    for (final codeUnit in '$userId::$itemKey'.codeUnits) {
      value = 37 * value + codeUnit;
    }
    return 700000000 + ((value & 0x7fffffff) % 1000000);
  }

  DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

class _MoneyReminderPlan {
  const _MoneyReminderPlan({
    required this.title,
    required this.body,
    required this.scheduledDate,
    required this.payload,
    required this.daily,
  });

  final String title;
  final String body;
  final tz.TZDateTime scheduledDate;
  final String payload;
  final bool daily;
}

/// 供调试 / 设置页展示：当前系统里挂着多少条记账预约。
Future<int> countScheduledMoneyReminders(AppNotificationService service) async {
  final pending = await service.pendingNotifications();
  final count = pending.where((request) => request.id >= 700000000).length;
  return math.min(count, MoneyReminderScheduler.maxScheduledReminders);
}
