import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/core/notifications/app_notification_service.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_commitment_entity.dart';
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
    Map<String, MoneyBudgetCommitment> commitments =
        const <String, MoneyBudgetCommitment>{},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateOnly((now ?? DateTime.now)());
    for (final budget in budgets) {
      final alert = _budgetAlertFor(budget, commitments[budget.id]);
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
        // 预算超支是结果而不是待办，点进去看预算面板比看提醒中心有用。
        payload: NotificationPayloads.moneyBudgets,
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

  /// [commitment] 是本周期内被未来义务占掉的额度。
  ///
  /// 「已用 60%，额度其实已经被预留吃满」这种状态必须提醒，否则用户会在
  /// 自动入账那天才发现早就没钱了。但**已超支的红线仍然只看已用**——
  /// 没发生的支出不该被说成已经超支。
  _BudgetAlert? _budgetAlertFor(
    MoneyBudgetEntity budget,
    MoneyBudgetCommitment? commitment,
  ) {
    if (!budget.isActive || !budget.alertEnabled || budget.amountMinor <= 0) {
      return null;
    }
    final committed = commitment?.totalMinor ?? 0;
    final projectedUsed = budget.usedAmountMinor + committed;
    final projectedProgress = projectedUsed / budget.amountMinor;

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

    // 还没超支，但已用 + 已预留已经吃满额度：提前一次说清楚，
    // 而不是等自动入账当天突然跳「已超支」。
    if (committed > 0 && projectedProgress >= 1) {
      final reservedText =
          '已用 ${formatMoneyMinor(budget.usedAmountMinor, budget.currencyCode)}，'
          '未来义务还将占用 ${formatMoneyMinor(committed, budget.currencyCode)}，';
      return _BudgetAlert(
        stage: 'reserved',
        title: budget.isIncomeTarget ? '收入目标额度已被占满' : '预算额度已被预留占满',
        body:
            '${budget.name} $reservedText'
            '合计 ${formatMoneyMinor(projectedUsed, budget.currencyCode)}'
            '${budget.isIncomeTarget ? '，目标' : '，预算'}'
            ' ${formatMoneyMinor(budget.amountMinor, budget.currencyCode)}。',
      );
    }

    final threshold = budget.alertThresholdPercent;
    if (threshold == null ||
        threshold <= 0 ||
        projectedProgress * 100 < threshold) {
      return null;
    }

    // 只靠已用还没到提醒线、算上预留才到：必须写明「含已预留」，
    // 否则用户一对账就发现数字对不上，会以为提醒算错了。
    final reservedNote = committed > 0 && budget.progress * 100 < threshold
        ? '（含已预留 ${formatMoneyMinor(committed, budget.currencyCode)}）'
        : '';

    if (budget.isIncomeTarget) {
      return _BudgetAlert(
        stage: '$threshold',
        title: '收入目标已达 $threshold%',
        body:
            '${budget.name} 已使用 ${_percentText(projectedProgress)}，达到 $threshold% 提醒线。'
            ' 当前已达 ${formatMoneyMinor(budget.usedAmountMinor, budget.currencyCode)}'
            '$reservedNote，'
            '目标 ${formatMoneyMinor(budget.amountMinor, budget.currencyCode)}。',
      );
    }
    return _BudgetAlert(
      stage: '$threshold',
      title: '预算已达 $threshold%',
      body:
          '${budget.name} 已使用 ${_percentText(projectedProgress)}，达到 $threshold% 提醒线。'
          ' 当前已用 ${formatMoneyMinor(budget.usedAmountMinor, budget.currencyCode)}'
          '$reservedNote，'
          '还可花 ${formatMoneyMinor(_availableMinor(budget, committed), budget.currencyCode)}。',
    );
  }

  int _availableMinor(MoneyBudgetEntity budget, int committedMinor) {
    final available = budget.remainingAmountMinor - committedMinor;
    return available < 0 ? 0 : available;
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
