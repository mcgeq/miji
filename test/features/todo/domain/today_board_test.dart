import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/todo/domain/today_board.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

/// 2026-10-20（周二）09:00，本地时间。
final DateTime now = DateTime(2026, 10, 20, 9);

TodoTask todo({
  required String id,
  DateTime? dueAt,
  DateTime? scheduledDate,
  DateTime? occurrenceDate,
  TodoTaskStatus status = TodoTaskStatus.todo,
  TodoTaskPriority priority = TodoTaskPriority.none,
  DateTime? completedAt,
}) => TodoTask(
  id: id,
  userId: 'u1',
  title: id,
  status: status,
  priority: priority,
  dueAt: dueAt,
  scheduledDate: scheduledDate,
  occurrenceDate: occurrenceDate,
  completedAt: completedAt,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

TodayTodoActionItem todoItem(TodoTask task) => TodayTodoActionItem(task: task);

/// 一个够用的打卡项：只需要 `plan.name` 与完成率。
///
/// `completionRate` 是派生的（`currentValue / targetValue`），不是构造参数；
/// 默认 `targetValue = 1`，所以 `currentValue` 直接就是完成率。
TodayHabitActionItem habitItem(String name, {double rate = 0}) =>
    TodayHabitActionItem(
      progress: PlanProgress(
        plan: CheckinPlan(
          id: name,
          userId: 'u1',
          name: name,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        ),
        currentCount: rate >= 1 ? 1 : 0,
        currentValue: rate,
      ),
    );

TodaySectionKind kindOf(TodayBoard board, String taskId) {
  for (final section in board.sections) {
    for (final item in section.items) {
      if (item.id == taskId) return section.kind;
    }
  }
  throw StateError('$taskId 不在任何段里');
}

void main() {
  group('分段归组', () {
    test('段序固定为 逾期 → 随时 → 上午 → 下午 → 晚上 → 打卡 → 已完成', () {
      final board = buildTodayBoard(
        items: [
          todoItem(todo(id: 'evening', dueAt: DateTime(2026, 10, 20, 20))),
          todoItem(todo(id: 'morning', dueAt: DateTime(2026, 10, 20, 9))),
          todoItem(todo(id: 'anytime')),
          todoItem(todo(id: 'overdue', scheduledDate: DateTime(2026, 10, 18))),
          todoItem(todo(id: 'afternoon', dueAt: DateTime(2026, 10, 20, 15))),
          habitItem('喝水'),
          todoItem(
            todo(
              id: 'done',
              status: TodoTaskStatus.completed,
              completedAt: DateTime(2026, 10, 20, 8),
            ),
          ),
        ],
        now: now,
      );

      expect(board.visibleSections.map((s) => s.kind).toList(), [
        TodaySectionKind.overdue,
        TodaySectionKind.anytime,
        TodaySectionKind.morning,
        TodaySectionKind.afternoon,
        TodaySectionKind.evening,
        TodaySectionKind.habit,
        TodaySectionKind.completed,
      ]);
    });

    test('「随时」紧跟逾期，排在有时间的任务之前', () {
      // 这是刻意决策：先清掉没有时间约束的杂事，再进入有时间约束的日程。
      final board = buildTodayBoard(
        items: [
          todoItem(todo(id: 'morning', dueAt: DateTime(2026, 10, 20, 9))),
          todoItem(todo(id: 'anytime')),
        ],
        now: now,
      );
      expect(board.visibleSections.first.kind, TodaySectionKind.anytime);
    });

    test('逾期永远置顶，哪怕它有具体时间', () {
      // morning 的时间刻意放在 09:00 之后：它不是逾期，只是有时间约束。
      final board = buildTodayBoard(
        items: [
          todoItem(todo(id: 'morning', dueAt: DateTime(2026, 10, 20, 10))),
          todoItem(todo(id: 'overdue', dueAt: DateTime(2026, 10, 19, 23))),
        ],
        now: now,
      );
      expect(kindOf(board, 'morning'), TodaySectionKind.morning);
      expect(kindOf(board, 'overdue'), TodaySectionKind.overdue);
      expect(board.visibleSections.first.kind, TodaySectionKind.overdue);
    });

    test('没有 dueAt 的进「随时」，不是「上午」', () {
      final board = buildTodayBoard(
        items: [todoItem(todo(id: 'a', scheduledDate: DateTime(2026, 10, 20)))],
        now: now,
      );
      expect(kindOf(board, 'a'), TodaySectionKind.anytime);
    });

    test('时间边界：06–12 上午 / 12–18 下午 / 其余晚上', () {
      // 用当天 00:00 作为参照点：否则 06:00、02:00 这类时刻在 09:00 看就已经
      // 逾期了，测的就不是「归哪一段」而是「是否逾期」。
      final board = buildTodayBoard(
        now: DateTime(2026, 10, 20),
        items: [
          todoItem(todo(id: 'a', dueAt: DateTime(2026, 10, 20, 6))),
          todoItem(todo(id: 'b', dueAt: DateTime(2026, 10, 20, 11, 59))),
          todoItem(todo(id: 'c', dueAt: DateTime(2026, 10, 20, 12))),
          todoItem(todo(id: 'd', dueAt: DateTime(2026, 10, 20, 17, 59))),
          todoItem(todo(id: 'e', dueAt: DateTime(2026, 10, 20, 18))),
          // 深夜归到「晚上」而不是单开一段：标「晚上」比标「凌晨」友好。
          todoItem(todo(id: 'f', dueAt: DateTime(2026, 10, 20, 2))),
        ],
      );
      expect(kindOf(board, 'a'), TodaySectionKind.morning);
      expect(kindOf(board, 'b'), TodaySectionKind.morning);
      expect(kindOf(board, 'c'), TodaySectionKind.afternoon);
      expect(kindOf(board, 'd'), TodaySectionKind.afternoon);
      expect(kindOf(board, 'e'), TodaySectionKind.evening);
      expect(kindOf(board, 'f'), TodaySectionKind.evening);
    });

    test('打卡单独成段，不混进时间分段', () {
      final board = buildTodayBoard(
        items: [
          todoItem(todo(id: 'a', dueAt: DateTime(2026, 10, 20, 9))),
          habitItem('喝水'),
        ],
        now: now,
      );
      expect(kindOf(board, '喝水'), TodaySectionKind.habit);
    });

    test('已完成的只进「已完成」段', () {
      final board = buildTodayBoard(
        items: [
          habitItem('洗澡', rate: 1),
          todoItem(
            todo(
              id: 'done',
              status: TodoTaskStatus.completed,
              completedAt: DateTime(2026, 10, 20, 8),
            ),
          ),
        ],
        now: now,
      );
      expect(kindOf(board, '洗澡'), TodaySectionKind.completed);
      expect(kindOf(board, 'done'), TodaySectionKind.completed);
      expect(board.completedCount, 2);
    });
  });

  group('段内排序', () {
    test('逾期段：拖得最久的排最前', () {
      final board = buildTodayBoard(
        items: [
          todoItem(todo(id: 'one', scheduledDate: DateTime(2026, 10, 19))),
          todoItem(todo(id: 'three', scheduledDate: DateTime(2026, 10, 17))),
          todoItem(todo(id: 'two', scheduledDate: DateTime(2026, 10, 18))),
        ],
        now: now,
      );
      final overdue = board.sectionOf(TodaySectionKind.overdue)!;
      expect(overdue.items.map((i) => i.id).toList(), ['three', 'two', 'one']);
    });

    test('时间分段：按 dueAt 升序', () {
      final board = buildTodayBoard(
        items: [
          todoItem(todo(id: 'late', dueAt: DateTime(2026, 10, 20, 11))),
          todoItem(todo(id: 'early', dueAt: DateTime(2026, 10, 20, 10))),
        ],
        now: now,
      );
      final morning = board.sectionOf(TodaySectionKind.morning)!;
      expect(morning.items.map((i) => i.id).toList(), ['early', 'late']);
    });

    test('随时段：优先级是唯一排序依据', () {
      final board = buildTodayBoard(
        items: [
          todoItem(todo(id: 'low', priority: TodoTaskPriority.low)),
          todoItem(todo(id: 'high', priority: TodoTaskPriority.high)),
          todoItem(todo(id: 'none')),
        ],
        now: now,
      );
      final anytime = board.sectionOf(TodaySectionKind.anytime)!;
      expect(anytime.items.map((i) => i.id).toList(), ['high', 'low', 'none']);
    });
  });

  group('计数与 HUD', () {
    test('环内显示剩余件数，不是完成百分比', () {
      final board = buildTodayBoard(
        items: [
          todoItem(todo(id: 'a')),
          todoItem(todo(id: 'b')),
          todoItem(
            todo(
              id: 'c',
              status: TodoTaskStatus.completed,
              completedAt: DateTime(2026, 10, 20, 8),
            ),
          ),
        ],
        now: now,
      );
      expect(board.totalCount, 3);
      expect(board.completedCount, 1);
      expect(board.remainingCount, 2);
      expect(board.isAllDone, isFalse);
    });

    test('全部完成时 isAllDone 为真', () {
      final board = buildTodayBoard(
        items: [habitItem('洗澡', rate: 1)],
        now: now,
      );
      expect(board.remainingCount, 0);
      expect(board.isAllDone, isTrue);
    });

    test('空列表：isEmpty，没有焦点', () {
      final board = buildTodayBoard(items: const [], now: now);
      expect(board.isEmpty, isTrue);
      expect(board.focus, isNull);
    });
  });

  group('最紧的一条', () {
    test('有逾期时取逾期里拖得最久的那条', () {
      final board = buildTodayBoard(
        items: [
          todoItem(todo(id: 'one', scheduledDate: DateTime(2026, 10, 19))),
          todoItem(todo(id: 'three', scheduledDate: DateTime(2026, 10, 17))),
          todoItem(todo(id: 'morning', dueAt: DateTime(2026, 10, 20, 8))),
        ],
        now: now,
      );
      expect(board.focus?.item.id, 'three');
      expect(board.focus?.isOverdue, isTrue);
    });

    test('没有逾期时取第一个非空段的第一条（随时优先于上午）', () {
      final board = buildTodayBoard(
        items: [
          todoItem(todo(id: 'morning', dueAt: DateTime(2026, 10, 20, 9))),
          todoItem(todo(id: 'anytime')),
        ],
        now: now,
      );
      expect(board.focus?.item.id, 'anytime');
      expect(board.focus?.isOverdue, isFalse);
    });

    test('已完成段不当焦点', () {
      final board = buildTodayBoard(
        items: [habitItem('洗澡', rate: 1)],
        now: now,
      );
      expect(board.focus, isNull);
    });

    test('标题读法是统一的', () {
      expect(todoItem(todo(id: '写周报')).displayTitle, '写周报');
      expect(habitItem('喝水').displayTitle, '喝水');
    });
  });

  group('待安排判定', () {
    test('既没排期日也没截止日的才算待安排', () {
      expect(isUnscheduledTodo(todo(id: 'a')), isTrue);
    });

    test('有 scheduledDate 的不算', () {
      expect(
        isUnscheduledTodo(todo(id: 'a', scheduledDate: DateTime(2026, 10, 20))),
        isFalse,
      );
    });

    test('有 dueAt 的不算', () {
      expect(
        isUnscheduledTodo(todo(id: 'a', dueAt: DateTime(2026, 10, 20, 9))),
        isFalse,
      );
    });

    test('重复实例不算 —— 否则一次补 30 天会把未来一个月全列进来', () {
      expect(
        isUnscheduledTodo(
          todo(id: 'a', occurrenceDate: DateTime(2026, 10, 21)),
        ),
        isFalse,
      );
    });

    test('已完成的不算', () {
      expect(
        isUnscheduledTodo(todo(id: 'a', status: TodoTaskStatus.completed)),
        isFalse,
      );
    });
  });
}
