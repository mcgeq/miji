import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

TodoTask task(String id, String title) => TodoTask(
  id: id,
  userId: 'u1',
  title: title,
  status: TodoTaskStatus.todo,
  priority: TodoTaskPriority.none,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

void main() {
  test('todo items keep provider order and cap', () {
    final view = TodayActionView(
      items: [
        for (var i = 0; i < 8; i++)
          TodayTodoActionItem(task: task('$i', 'T$i')),
      ],
      completedCount: 0,
      totalCount: 8,
    );
    final brief = buildHomeActionBrief(view: view, habits: const [], cap: 5);
    expect(brief.todos.length, 5);
    expect(brief.completedCount, 0);
    expect(brief.totalCount, 8);
  });

  test('habit items map progress', () {
    final plan = CheckinPlan(
      id: 'p1',
      userId: 'u1',
      name: '阅读',
      icon: '📖',
      targetValue: 30,
      targetUnit: '页',
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    final progress = PlanProgress(
      plan: plan,
      currentCount: 1,
      currentValue: 20,
      streak: 12,
    );
    final brief = buildHomeActionBrief(
      view: const TodayActionView(items: [], completedCount: 0, totalCount: 0),
      habits: [progress],
      cap: 5,
    );
    expect(brief.habits.single.name, '阅读');
    expect(brief.habits.single.progressLabel, '20/30 页');
    expect(brief.habits.single.streak, 12);
    expect(brief.habits.single.isDone, isFalse);
  });

  test('empty view produces empty brief', () {
    final brief = buildHomeActionBrief(view: null, habits: const [], cap: 5);
    expect(brief.todos, isEmpty);
    expect(brief.totalCount, 0);
  });
}
