import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';
import 'package:miji/features/home/presentation/home_action_todo_card.dart';
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

Widget host(HomeActionTodoCard card) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: card),
);

void main() {
  testWidgets('shows title and toggles a task', (tester) async {
    TodoTask? toggled;
    await tester.pumpWidget(
      host(
        HomeActionTodoCard(
          brief: HomeActionBrief(
            todos: [HomeTodoEntry(task: task('1', '交房租'))],
            habits: const [],
            completedCount: 0,
            totalCount: 1,
            streakDays: 7,
          ),
          onToggle: (t) => toggled = t,
          onAdd: () {},
          onEdit: (_) {},
          onDelete: (_) {},
          onOpenAll: () {},
        ),
      ),
    );

    expect(find.text('交房租'), findsOneWidget);
    expect(find.text('🔥 连续 7 天'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.radio_button_unchecked_rounded));
    expect(toggled?.id, '1');
  });

  testWidgets('add button fires callback', (tester) async {
    var added = 0;
    await tester.pumpWidget(
      host(
        HomeActionTodoCard(
          brief: HomeActionBrief.empty,
          onToggle: (_) {},
          onAdd: () => added++,
          onEdit: (_) {},
          onDelete: (_) {},
          onOpenAll: () {},
        ),
      ),
    );
    expect(find.text('今天没有待办'), findsOneWidget);
    await tester.tap(find.text('添加待办'));
    expect(added, 1);
  });
}
