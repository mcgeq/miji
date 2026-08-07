import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/core/notifications/app_notification_service.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';

class MoneyBudgetAlertNotificationService {
  const MoneyBudgetAlertNotificationService({
    required this.notificationService,
    this.now,
  });

  final AppNotificationService notificationService;
  final DateTime Function()? now;

  Future<void> scanAndNotify({
    required String userId,
    required List<MoneyBudgetEntity> budgets,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateOnly((now ?? DateTime.now)());
    for (final budget in budgets) {
      final alert = _budgetAlertFor(budget);
      final storageKey = _storageKey(userId, budget.id);
      if (alert == null) {
        await prefs.remove(storageKey);
        continue;
      }
      if (await _isSnoozed(prefs, userId, budget.id, today)) {
        continue;
      }

      final alertToken = _alertToken(budget, alert, today);
      if (prefs.getString(storageKey) == alertToken) {
        continue;
      }

      final shown = await notificationService.showBudgetAlert(
        id: _notificationId(userId, budget.id),
        title: alert.title,
        body: alert.body,
        payload: budget.id,
      );
      if (shown) {
        await prefs.setString(storageKey, alertToken);
      } else {
        debugPrint(
          '[budget-alert] 通知发送失败（权限未授予或平台不支持）：'
          'budget=${budget.id} stage=${alert.stage}',
        );
      }
    }
  }

  Future<void> snoozeBudgetAlert({
    required String userId,
    required String budgetId,
    required DateTime until,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _snoozeKey(userId, budgetId),
      _dateOnly(until).millisecondsSinceEpoch,
    );
  }

  Future<void> clearBudgetAlertSnooze({
    required String userId,
    required String budgetId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snoozeKey(userId, budgetId));
  }

  _BudgetAlert? _budgetAlertFor(MoneyBudgetEntity budget) {
    if (!budget.isActive || !budget.alertEnabled || budget.amountMinor <= 0) {
      return null;
    }

    if (budget.progress >= 1) {
      if (budget.isIncomeTarget) {
        return _BudgetAlert(
          stage: '100',
          title: '收入目标已达 100%',
          body:
              '${budget.name} 已完成，目标 ${formatMoneyMinor(budget.amountMinor, budget.currencyCode)}，'
              '当前已达 ${formatMoneyMinor(budget.usedAmountMinor, budget.currencyCode)}。',
        );
      }
      return _BudgetAlert(
        stage: '100',
        title: '预算已达 100%',
        body:
            '${budget.name} 已使用 ${_percentText(budget.progress)}，'
            '当前已用 ${formatMoneyMinor(budget.usedAmountMinor, budget.currencyCode)}。'
            '预算金额 ${formatMoneyMinor(budget.amountMinor, budget.currencyCode)}。',
      );
    }

    final threshold = budget.alertThresholdPercent;
    if (threshold == null ||
        threshold <= 0 ||
        budget.progress * 100 < threshold) {
      return null;
    }

    if (budget.isIncomeTarget) {
      return _BudgetAlert(
        stage: '$threshold',
        title: '收入目标已达 $threshold%',
        body:
            '${budget.name} 已使用 ${_percentText(budget.progress)}，达到 $threshold% 提醒线。'
            ' 当前已达 ${formatMoneyMinor(budget.usedAmountMinor, budget.currencyCode)}，'
            '目标 ${formatMoneyMinor(budget.amountMinor, budget.currencyCode)}。',
      );
    }
    return _BudgetAlert(
      stage: '$threshold',
      title: '预算已达 $threshold%',
      body:
          '${budget.name} 已使用 ${_percentText(budget.progress)}，达到 $threshold% 提醒线。'
          ' 当前已用 ${formatMoneyMinor(budget.usedAmountMinor, budget.currencyCode)}，'
          '剩余 ${formatMoneyMinor(budget.remainingAmountMinor, budget.currencyCode)}。',
    );
  }

  Future<bool> _isSnoozed(
    SharedPreferences prefs,
    String userId,
    String budgetId,
    DateTime today,
  ) async {
    final snoozedUntilMillis = prefs.getInt(_snoozeKey(userId, budgetId));
    if (snoozedUntilMillis == null) {
      return false;
    }
    final snoozedUntil = _dateOnly(
      DateTime.fromMillisecondsSinceEpoch(snoozedUntilMillis),
    );
    if (today.isBefore(snoozedUntil)) {
      return true;
    }
    await prefs.remove(_snoozeKey(userId, budgetId));
    return false;
  }

  String _alertToken(
    MoneyBudgetEntity budget,
    _BudgetAlert alert,
    DateTime today,
  ) {
    return '${budget.periodStart.millisecondsSinceEpoch}:${_dateKey(today)}:${alert.stage}';
  }

  String _storageKey(String userId, String budgetId) {
    return 'budget_alert::$userId::$budgetId';
  }

  String _snoozeKey(String userId, String budgetId) {
    return 'budget_alert_snooze::$userId::$budgetId';
  }

  int _notificationId(String userId, String budgetId) {
    var value = 17;
    for (final codeUnit in '$userId::$budgetId'.codeUnits) {
      value = 31 * value + codeUnit;
    }
    return value & 0x7fffffff;
  }

  String _percentText(double progress) {
    return '${(progress * 100).clamp(0, 999).toStringAsFixed(0)}%';
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _BudgetAlert {
  const _BudgetAlert({
    required this.stage,
    required this.title,
    required this.body,
  });

  /// 触发阶段标识（如 '70'、'90'、'100'），参与通知去重 token。
  final String stage;
  final String title;
  final String body;
}
