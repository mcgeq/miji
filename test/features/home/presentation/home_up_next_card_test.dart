import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';
import 'package:miji/features/home/presentation/home_up_next_card.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

TodoTask task(String id, String title) => TodoTask(
  id: id,
  userId: 'u1',
  title: title,
  status: TodoTaskStatus.todo,
  priority: TodoTaskPriority.none,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

HomeActionBrief brief(List<TodoTask> tasks) => HomeActionBrief(
  todos: [for (final t in tasks) HomeTodoEntry(task: t)],
  habits: const [],
  completedCount: 0,
  totalCount: tasks.length,
  streakDays: 0,
);

Widget host(Widget child) =>
    MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('caps at three items', (tester) async {
    await tester.pumpWidget(
      host(
        HomeUpNextCard(
          brief: brief([
            task('1', 'A'),
            task('2', 'B'),
            task('3', 'C'),
            task('4', 'D'),
          ]),
          onToggle: (_) {},
          onAdd: () {},
          onOpenAll: () {},
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsNothing);
  });

  testWidgets('tapping a row toggles it', (tester) async {
    TodoTask? toggled;
    await tester.pumpWidget(
      host(
        HomeUpNextCard(
          brief: brief([task('1', '交房租')]),
          onToggle: (t) => toggled = t,
          onAdd: () {},
          onOpenAll: () {},
        ),
      ),
    );
    await tester.tap(find.text('交房租'));
    expect(toggled?.id, '1');
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(
      host(
        HomeUpNextCard(
          brief: HomeActionBrief.empty,
          onToggle: (_) {},
          onAdd: () {},
          onOpenAll: () {},
        ),
      ),
    );
    expect(find.text('今天没有待办'), findsOneWidget);
  });
}
