import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

/// 2026-10-20 09:00，本地时间。
final DateTime now = DateTime(2026, 10, 20, 9);

TodoTask task({
  DateTime? dueAt,
  DateTime? scheduledDate,
  DateTime? occurrenceDate,
  TodoTaskStatus status = TodoTaskStatus.todo,
}) => TodoTask(
  id: 't1',
  userId: 'u1',
  title: '写周报',
  status: status,
  priority: TodoTaskPriority.none,
  dueAt: dueAt,
  scheduledDate: scheduledDate,
  occurrenceDate: occurrenceDate,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

void main() {
  group('plannedDay', () {
    test('dueAt 优先于 scheduledDate，且收敛到日', () {
      final t = task(
        dueAt: DateTime(2026, 10, 22, 18, 30),
        scheduledDate: DateTime(2026, 10, 20),
      );
      expect(t.plannedDay, DateTime(2026, 10, 22));
    });

    test('没有 dueAt 时退回 scheduledDate', () {
      expect(
        task(scheduledDate: DateTime(2026, 10, 19)).plannedDay,
        DateTime(2026, 10, 19),
      );
    });

    test('重复实例不参与顺延口径', () {
      // 一次性补 30 天的实例，若把它们也顺延过来，一个长期没做的每日任务
      // 会在今天堆出几十条。
      expect(task(occurrenceDate: DateTime(2026, 10, 18)).plannedDay, isNull);
    });
  });

  group('isOverdueAt', () {
    test('昨天排的、今天还没做完 → 逾期', () {
      expect(
        task(scheduledDate: DateTime(2026, 10, 19)).isOverdueAt(now),
        isTrue,
      );
    });

    test('今天排的不算逾期', () {
      expect(
        task(scheduledDate: DateTime(2026, 10, 20)).isOverdueAt(now),
        isFalse,
      );
    });

    test('dueAt 按时刻算：今天 8 点截止、现在 9 点 → 逾期', () {
      expect(task(dueAt: DateTime(2026, 10, 20, 8)).isOverdueAt(now), isTrue);
    });

    test('dueAt 还没到 → 不逾期（哪怕排期是昨天）', () {
      // 「排昨天、下周三截止」不该被提前拉进今天。
      expect(
        task(
          scheduledDate: DateTime(2026, 10, 19),
          dueAt: DateTime(2026, 10, 21, 9),
        ).isOverdueAt(now),
        isFalse,
      );
    });

    test('已完成 / 已取消的不算逾期', () {
      expect(
        task(
          scheduledDate: DateTime(2026, 10, 18),
          status: TodoTaskStatus.completed,
        ).isOverdueAt(now),
        isFalse,
      );
    });

    test('没有日期的任务永远不逾期', () {
      expect(task().isOverdueAt(now), isFalse);
    });
  });

  group('overdueDaysAt / overdueLabelAt', () {
    test('拖了几天算得出来', () {
      expect(task(scheduledDate: DateTime(2026, 10, 19)).overdueDaysAt(now), 1);
      expect(task(scheduledDate: DateTime(2026, 10, 17)).overdueDaysAt(now), 3);
    });

    test('顺延过来的任务显示「逾期 N 天」', () {
      expect(
        task(scheduledDate: DateTime(2026, 10, 17)).overdueLabelAt(now),
        '逾期 3 天',
      );
    });

    test('今天刚过点的只显示「逾期」', () {
      expect(task(dueAt: DateTime(2026, 10, 20, 8)).overdueLabelAt(now), '逾期');
    });

    test('没逾期就没有文案', () {
      expect(
        task(scheduledDate: DateTime(2026, 10, 20)).overdueLabelAt(now),
        '',
      );
    });
  });
}
