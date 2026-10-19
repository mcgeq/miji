import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/home/application/home_unified_reminders_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

final _now = DateTime(2026, 10, 12, 9);

TodoTask task(
  String id,
  String title, {
  DateTime? dueAt,
  DateTime? scheduledDate,
  TodoTaskStatus status = TodoTaskStatus.todo,
}) => TodoTask(
  id: id,
  userId: 'u1',
  title: title,
  status: status,
  priority: TodoTaskPriority.none,
  dueAt: dueAt,
  scheduledDate: scheduledDate,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

CheckinPlan plan(String id, String name, {bool reminderEnabled = true}) =>
    CheckinPlan(
      id: id,
      userId: 'u1',
      name: name,
      icon: '📖',
      targetValue: 1,
      targetUnit: '次',
      reminderEnabled: reminderEnabled,
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );

HealthPeriodSettingsModel settings({
  bool period = true,
  bool ovulation = true,
  bool pms = true,
  int reminderDays = 3,
}) => HealthPeriodSettingsModel(
  averageCycleLength: 28,
  averagePeriodLength: 5,
  periodTrackingEnabled: true,
  periodReminderEnabled: period,
  ovulationReminderEnabled: ovulation,
  pmsReminderEnabled: pms,
  reminderDays: reminderDays,
  dataSyncEnabled: true,
  analyticsEnabled: false,
);

HealthTodaySnapshot snapshot({
  required HealthCyclePrediction prediction,
  HealthPeriodSettingsModel? s,
}) => HealthTodaySnapshot(
  date: DateTime.utc(2026, 10, 12),
  settings: s ?? settings(),
  prediction: prediction,
  activePeriod: null,
  dailyLog: HealthDailyLog.empty(DateTime.utc(2026, 10, 12)),
  activePregnancy: null,
);

void main() {
  group('todo reminders', () {
    test('flags overdue and due-today, ignores future and done', () {
      final items = buildTodoReminders([
        task('1', '逾期', dueAt: DateTime(2026, 10, 10, 18)),
        task('2', '今天', dueAt: DateTime(2026, 10, 12, 20)),
        task('3', '明天', dueAt: DateTime(2026, 10, 13, 20)),
        task(
          '4',
          '已完成',
          dueAt: DateTime(2026, 10, 10),
          status: TodoTaskStatus.completed,
        ),
      ], _now);

      expect(items.length, 2);
      expect(
        items.firstWhere((i) => i.title == '逾期').severity,
        HomeReminderSeverity.overdue,
      );
      expect(
        items.firstWhere((i) => i.title == '今天').severity,
        HomeReminderSeverity.dueToday,
      );
    });
  });

  group('habit reminders', () {
    test('only plans with reminder enabled and not done', () {
      final items = buildHabitReminders([
        PlanProgress(plan: plan('1', '阅读'), currentValue: 0),
        PlanProgress(
          plan: plan('2', '运动', reminderEnabled: false),
          currentValue: 0,
        ),
        PlanProgress(plan: plan('3', '冥想'), currentValue: 1),
      ]);
      expect(items.map((i) => i.title).toList(), ['阅读']);
    });
  });

  group('health reminders', () {
    test('period due within reminder window', () {
      final items = buildHealthReminders(
        snapshot(
          prediction: HealthCyclePrediction.cycleDay(
            basis: HealthPredictionBasis.history,
            mainStatus: '',
            currentCycleDay: 26,
            daysUntilNextPeriod: 2,
            nextPeriodStart: DateTime.utc(2026, 10, 14),
            nextPeriodEnd: DateTime.utc(2026, 10, 18),
            fertileWindowStart: DateTime.utc(2026, 10, 20),
            fertileWindowEnd: DateTime.utc(2026, 10, 25),
            pmsStart: DateTime.utc(2026, 10, 20),
            pmsEnd: DateTime.utc(2026, 10, 26),
          ),
        ),
        _now,
      );
      expect(items.any((i) => i.title.contains('经期预计 2 天')), isTrue);
    });

    test('returns nothing when tracking off', () {
      final items = buildHealthReminders(null, _now);
      expect(items, isEmpty);
    });
  });

  group('与「接下来」按时间切分', () {
    test('明天及以后到期的不进「需要关注」', () {
      final result = buildHomeUnifiedReminders(
        money: const [],
        budgets: const [],
        todos: [task('1', '明天', dueAt: DateTime(2026, 10, 13, 20))],
        habits: const [],
        health: null,
        now: _now,
      );
      expect(result.items, isEmpty);
    });

    test('3 天后到期的账单不进（交给「接下来」预览）', () {
      final result = buildHomeUnifiedReminders(
        money: [
          MoneyReminderCenterItem(
            sourceType: MoneyReminderCenterSourceType.billReminder,
            sourceId: 'b1',
            title: '房租',
            dueDate: DateTime(2026, 10, 15),
            amountMinor: 350000,
            currencyCode: 'CNY',
            actionType: MoneyReminderCenterActionType.recordTransaction,
          ),
        ],
        budgets: const [],
        todos: const [],
        habits: const [],
        health: null,
        now: _now,
      );
      expect(result.items, isEmpty);
    });

    test('预算超支例外：它没有到期日，属于「现在」', () {
      final result = buildHomeUnifiedReminders(
        money: [
          MoneyReminderCenterItem(
            sourceType: MoneyReminderCenterSourceType.budget,
            sourceId: 'bud1',
            title: '餐饮超支',
            dueDate: DateTime(2026, 10, 30),
            amountMinor: 12000,
            currencyCode: 'CNY',
            actionType: MoneyReminderCenterActionType.viewBudget,
            isBudgetExceeded: true,
          ),
        ],
        budgets: const [],
        todos: const [],
        habits: const [],
        health: null,
        now: _now,
      );
      expect(result.items.single.title, '餐饮超支');
    });

    test('逾期、今天到期、今天没打卡都留下', () {
      final result = buildHomeUnifiedReminders(
        money: const [],
        budgets: const [],
        todos: [
          task('1', '逾期', dueAt: DateTime(2026, 10, 8)),
          task('2', '今天', dueAt: DateTime(2026, 10, 12, 20)),
        ],
        habits: [PlanProgress(plan: plan('h', '阅读'), currentValue: 0)],
        health: null,
        now: _now,
      );
      expect(result.items.map((i) => i.title).toList(), ['逾期', '今天', '阅读']);
    });
  });

  group('merge and sort', () {
    test('orders overdue before due-today before due-soon', () {
      final result = buildHomeUnifiedReminders(
        money: const [],
        budgets: const [],
        todos: [
          task('1', '今天', dueAt: DateTime(2026, 10, 12, 20)),
          task('2', '逾期', dueAt: DateTime(2026, 10, 8)),
        ],
        habits: [PlanProgress(plan: plan('h', '阅读'), currentValue: 0)],
        health: null,
        now: _now,
      );
      expect(result.items.first.title, '逾期');
      expect(result.items[1].source, HomeReminderSource.todo);
      expect(result.items[1].title, '今天');
    });

    test('maps money severity', () {
      final items = buildMoneyReminders(
        [
          MoneyReminderCenterItem(
            sourceType: MoneyReminderCenterSourceType.creditCardBill,
            sourceId: 'c1',
            title: '信用卡还款',
            dueDate: _now,
            amountMinor: 234050,
            currencyCode: 'CNY',
            actionType: MoneyReminderCenterActionType.repay,
          ),
        ],
        const [],
        _now,
      );
      expect(items.single.source, HomeReminderSource.money);
      expect(items.single.severity, HomeReminderSeverity.dueToday);
      expect(items.single.amountMinor, 234050);
    });
  });
}
