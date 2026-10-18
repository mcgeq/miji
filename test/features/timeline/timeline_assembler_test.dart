import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/bookkeeping/domain/money_budget_commitment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/timeline/domain/timeline_assembler.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

/// 组装是纯函数：输入各模块已有的领域对象，输出「哪条事件属于哪天、属于哪一类」。
/// 这一层不查库，所以这些用例都是同步的。
void main() {
  final day = DateTime.utc(2026, 10, 18);
  TimelineWindow week() => TimelineWindow.weekOf(day);

  MoneyTransactionEntity transaction({
    String id = 't1',
    String description = '午餐',
    int amountMinor = 3800,
    DateTime? at,
    MoneyTransactionType type = MoneyTransactionType.expense,
  }) {
    final when = at ?? DateTime.utc(2026, 10, 18, 12, 10);
    return MoneyTransactionEntity(
      id: id,
      userId: 'user-1',
      type: type,
      status: MoneyTransactionStatus.completed,
      transactionAt: when,
      amountMinor: amountMinor,
      refundAmountMinor: 0,
      currencyCode: 'CNY',
      description: description,
      notes: null,
      merchant: null,
      location: null,
      accountId: 'acc-1',
      toAccountId: null,
      categoryId: 'cat-1',
      subCategoryId: null,
      paymentMethod: MoneyPaymentMethod.alipay,
      customPaymentMethodName: null,
      actualPayerAccount: 'self',
      relatedTransactionId: null,
      installmentPlanId: null,
      sourceTemplateRunId: null,
      interestRateBasisPoints: null,
      totalInterestMinor: 0,
      calcMethod: null,
      tags: const <String>[],
      isDeleted: false,
      createdAt: when,
      updatedAt: when,
    );
  }

  MoneyBudgetCommitmentItem commitment({
    String title = '房贷',
    DateTime? date,
    int amountMinor = 800000,
    MoneyBudgetCommitmentSource source =
        MoneyBudgetCommitmentSource.autoPosting,
  }) {
    return MoneyBudgetCommitmentItem(
      source: source,
      sourceId: 'src-1',
      title: title,
      date: date ?? DateTime.utc(2026, 10, 17),
      amountMinor: amountMinor,
      detail: '自动记账',
      currencyCode: 'CNY',
    );
  }

  TodoTask task({
    String id = 'task-1',
    String title = '体检预约',
    DateTime? scheduled,
    DateTime? dueAt,
    DateTime? completedAt,
    String? recurrenceRuleId,
  }) {
    return TodoTask(
      id: id,
      userId: 'user-1',
      title: title,
      status: completedAt == null ? TodoTaskStatus.todo : TodoTaskStatus.completed,
      priority: TodoTaskPriority.medium,
      scheduledDate: scheduled,
      dueAt: dueAt,
      completedAt: completedAt,
      recurrenceRuleId: recurrenceRuleId,
      createdAt: day,
      updatedAt: day,
    );
  }

  CheckinRecord record({
    String id = 'r1',
    String planId = 'plan-1',
    DateTime? recordDate,
    DateTime? completedAt,
  }) {
    final date = recordDate ?? day;
    final when = completedAt ?? DateTime.utc(2026, 10, 18, 7, 40);
    return CheckinRecord(
      id: id,
      userId: 'user-1',
      planId: planId,
      recordDate: date,
      completedAt: when,
      createdAt: when,
      updatedAt: when,
    );
  }

  HealthCalendarMarker marker(
    DateTime date,
    HealthCalendarMarkerKind kind,
    String label,
  ) {
    return HealthCalendarMarker(date: date, kind: kind, label: label);
  }

  Timeline build({
    Iterable<MoneyTransactionEntity> transactions = const [],
    Iterable<MoneyBudgetCommitmentItem> commitments = const [],
    Iterable<TodoTask> tasks = const [],
    Iterable<CheckinRecord> records = const [],
    Iterable<CheckinPlan> plans = const [],
    Iterable<HealthCalendarMarker> markers = const [],
  }) {
    return assembleTimeline(
      window: week(),
      eventGroups: [
        moneyEvents(transactions: transactions, commitments: commitments),
        todoEvents(tasks),
        habitEvents(records: records, plans: plans),
        healthEvents(markers),
      ],
    );
  }

  test('流水归到它发生的那一天，金额按收支给正负', () {
    final timeline = build(
      transactions: [
        transaction(id: 'a', at: DateTime.utc(2026, 10, 18, 12, 10)),
        transaction(
          id: 'b',
          type: MoneyTransactionType.income,
          amountMinor: 1200000,
          description: '工资',
          at: DateTime.utc(2026, 10, 17, 9),
        ),
      ],
    );

    expect(timeline.days, hasLength(2));
    // 12–18 这一周里只有 17、18 两天有流水。
    expect(timeline.days.first.day, DateTime.utc(2026, 10, 17));
    expect(timeline.days.first.facts.single.amountMinor, 1200000);
    expect(timeline.days.last.day, DateTime.utc(2026, 10, 18));
    expect(timeline.days.last.facts.single.amountMinor, -3800);
  });

  test('窗口外的事件不进来，窗口边界含首尾两天', () {
    final timeline = build(
      transactions: [
        transaction(id: 'out-before', at: DateTime.utc(2026, 10, 11, 23)),
        transaction(id: 'in-monday', at: DateTime.utc(2026, 10, 12, 0, 1)),
        transaction(id: 'in-sunday', at: DateTime.utc(2026, 10, 18, 23, 50)),
        transaction(id: 'out-after', at: DateTime.utc(2026, 10, 19, 0, 1)),
      ],
    );

    final days = timeline.days.map((d) => d.day).toList();
    expect(days.first, DateTime.utc(2026, 10, 12));
    expect(days.last, DateTime.utc(2026, 10, 18));
    expect(timeline.totalEvents, 2);
  });

  test('预测与事实分开装：经期预测不会被当成已发生', () {
    final timeline = build(
      markers: [
        marker(day, HealthCalendarMarkerKind.actualPeriod, '经期第 1 天'),
        marker(
          DateTime.utc(2026, 10, 17),
          HealthCalendarMarkerKind.predictedPeriod,
          '预计经期开始',
        ),
      ],
    );

    final predicted = timeline.days.first;
    final today = timeline.days.last;
    expect(today.facts.single.nature, TimelineNature.fact);
    expect(predicted.predictions.single.nature, TimelineNature.prediction);
    expect(predicted.facts, isEmpty);
    expect(predicted.predictions.single.subtitle, contains('推算'));
  });

  test('打卡一天聚合成一条，标题里给出次数与前几项名字', () {
    final timeline = build(
      records: [
        record(id: 'r1', planId: 'p1'),
        record(id: 'r2', planId: 'p2'),
        record(id: 'r3', planId: 'p3'),
        record(id: 'r4', planId: 'p4'),
      ],
      plans: [
        CheckinPlan(
          id: 'p1',
          userId: 'user-1',
          name: '喝水',
          createdAt: day,
          updatedAt: day,
        ),
      ],
    );

    final events = timeline.days.single.facts;
    expect(events, hasLength(1), reason: '四条记录应该聚合成一条');
    expect(events.single.title, '打卡 4 次');
    expect(events.single.subtitle, contains('喝水'));
  });

  test('待办：未完成是承诺，完成是事实；重复规则要标记出来', () {
    final timeline = build(
      tasks: [
        task(id: 'a', scheduled: day, title: '体检预约'),
        task(
          id: 'b',
          title: '每周复盘',
          dueAt: DateTime.utc(2026, 10, 17, 21),
          recurrenceRuleId: 'rule-1',
        ),
        task(
          id: 'c',
          title: '写周报',
          completedAt: DateTime.utc(2026, 10, 18, 18, 30),
        ),
      ],
    );

    final sunday = timeline.days.last;
    final friday = timeline.days.first;

    expect(sunday.commitments.single.title, '体检预约');
    expect(sunday.commitments.single.precision, TimelinePrecision.day);
    expect(sunday.facts.single.title, '写周报');

    final recurring = friday.commitments.single;
    expect(recurring.ruleId, 'rule-1');
    expect(recurring.target?.askRuleScope, isTrue);
  });

  test('一天的排序：全天在前，事实按时刻倒序', () {
    final timeline = build(
      commitments: [commitment(date: day, title: '全天还款')],
      transactions: [
        transaction(id: 'morning', description: '早餐', at: DateTime.utc(2026, 10, 18, 8)),
        transaction(id: 'noon', description: '午餐', at: DateTime.utc(2026, 10, 18, 12)),
      ],
    );

    final today = timeline.days.single;
    expect(today.commitments.single.isTimed, isFalse);
    expect(today.facts.first.title, '午餐');
    expect(today.facts.last.title, '早餐');
  });

  test('同一天超过上限时截断，并给出被截掉的条数', () {
    final timeline = assembleTimeline(
      window: TimelineWindow.dayOf(day),
      perDayLimit: 3,
      eventGroups: [
        moneyEvents(
          transactions: [
            for (var i = 0; i < 5; i++)
              transaction(
                id: 't$i',
                description: '支出 $i',
                at: DateTime.utc(2026, 10, 18, 9 + i),
              ),
          ],
        ),
      ],
    );

    final today = timeline.days.single;
    expect(today.facts, hasLength(3));
    expect(today.hiddenCount, 2);
  });

  test('同一身份的事件不会重复出现（两个来源撞车时）', () {
    final shared = transaction(id: 'dup', at: DateTime.utc(2026, 10, 18, 12));
    final timeline = assembleTimeline(
      window: week(),
      eventGroups: [
        moneyEvents(transactions: [shared]),
        moneyEvents(transactions: [shared]),
      ],
    );
    expect(timeline.days.single.facts, hasLength(1));
  });

  test('没有事件的日子不出现在结果里', () {
    final timeline = build(
      transactions: [transaction(at: DateTime.utc(2026, 10, 14, 12))],
    );
    expect(timeline.days, hasLength(1));
    expect(timeline.days.single.day, DateTime.utc(2026, 10, 14));
  });
}
