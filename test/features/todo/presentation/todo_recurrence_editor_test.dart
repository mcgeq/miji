import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/presentation/todo_recurrence_editor.dart';

/// 重复规则编辑器：它是跨模块时间线上「改整条规则」的目的地。
void main() {
  TodoRecurrenceRule rule({
    RecurrenceFrequencyType frequency = RecurrenceFrequencyType.weekly,
    int interval = 1,
    List<int>? daysOfWeek,
    int? dayOfMonth,
    DateTime? endsAt,
  }) {
    return TodoRecurrenceRule(
      id: 'rule-1',
      userId: 'user-1',
      templateTaskId: 'task-1',
      frequencyType: frequency,
      interval_: interval,
      daysOfWeek: daysOfWeek,
      dayOfMonth: dayOfMonth,
      endsAt: endsAt,
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
  }

  Future<void> pumpEditor(WidgetTester tester, TodoRecurrenceRule value) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<TodoRecurrenceRule>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => TodoRecurrenceEditor(rule: value),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  test('摘要能分清每天 / 每周几 / 每月几号 / 每 N 天', () {
    expect(
      describeRecurrenceRule(rule(frequency: RecurrenceFrequencyType.daily)),
      '每天',
    );
    expect(
      describeRecurrenceRule(
        rule(frequency: RecurrenceFrequencyType.weekly, daysOfWeek: [1, 3]),
      ),
      '每周一、三',
    );
    expect(
      describeRecurrenceRule(
        rule(frequency: RecurrenceFrequencyType.monthly, dayOfMonth: 15),
      ),
      '每月 15 日',
    );
    expect(
      describeRecurrenceRule(
        rule(
          frequency: RecurrenceFrequencyType.daily,
          interval: 2,
          endsAt: DateTime.utc(2026, 12, 31),
        ),
      ),
      '每 2 天 · 到 2026-12-31',
    );
  });

  testWidgets('打开时带出已有规则：每周选中的那天是亮的', (tester) async {
    await pumpEditor(
      tester,
      rule(frequency: RecurrenceFrequencyType.weekly, daysOfWeek: [1]),
    );

    expect(find.text('重复规则'), findsOneWidget);
    final monday = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '一'),
    );
    expect(monday.selected, isTrue);
    final wednesday = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '三'),
    );
    expect(wednesday.selected, isFalse);
  });

  testWidgets('每周一天都没选时保存不可用', (tester) async {
    await pumpEditor(
      tester,
      rule(frequency: RecurrenceFrequencyType.weekly, daysOfWeek: [1]),
    );

    await tester.tap(find.text('一'));
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存规则'),
    );
    expect(save.onPressed, isNull, reason: '一条规则都不选等于没规则');
  });

  testWidgets('切到每月：出现日期下拉；再切回每周：日期下拉消失', (tester) async {
    await pumpEditor(tester, rule(frequency: RecurrenceFrequencyType.daily));

    await tester.tap(find.text('每月'));
    await tester.pumpAndSettle();
    expect(find.textContaining('日'), findsWidgets);

    await tester.tap(find.text('每周'));
    await tester.pumpAndSettle();
    expect(find.text('保存规则'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新建模式：标题是「设为重复」，并给出一个可用的默认（本周几）', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<RecurrenceRuleSpec>(
                  context: context,
                  builder: (_) => const TodoRecurrenceEditor(),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('设为重复'), findsOneWidget);
    // 默认就是「每周 + 今天星期几」：比让用户从零挑一天更接近意图。
    final today = DateTime.now().weekday;
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, labels[today - 1]),
    );
    expect(chip.selected, isTrue);
    expect(find.text('保存规则'), findsOneWidget);
  });

  testWidgets('Spec 能落到已有规则上，也能变成一条新规则', (tester) async {
    const spec = RecurrenceRuleSpec(
      frequency: RecurrenceFrequencyType.monthly,
      interval: 3,
      dayOfMonth: 5,
    );

    final applied = spec.applyTo(
      rule(frequency: RecurrenceFrequencyType.daily),
    );
    expect(applied.id, 'rule-1', reason: '改整条规则：id 不变');
    expect(applied.frequencyType, RecurrenceFrequencyType.monthly);
    expect(applied.interval_, 3);

    final created = spec.toNewRule(userId: 'user-1');
    expect(created.id, isEmpty, reason: 'id / 模板由仓库填');
    expect(created.userId, 'user-1');
    expect(created.frequencyType, RecurrenceFrequencyType.monthly);
  });
}
