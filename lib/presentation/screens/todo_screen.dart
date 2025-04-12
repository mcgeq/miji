// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           todo_screen.dart
// Description:    About Todo Screen
// Create   Date:  2025-04-12 10:54:38
// Last Modified:  2025-04-12 10:54:46
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mcge_pisces/providers/todo_provider.dart';
import 'package:mcge_pisces/providers/todo_filter_provider.dart';
import 'package:mcge_pisces/presentation/widgets/todo_input.dart';
import 'package:mcge_pisces/presentation/widgets/filter_buttons.dart';
import 'package:mcge_pisces/presentation/widgets/todo_item.dart';
import 'package:mcge_pisces/presentation/widgets/pagination.dart';
import 'package:mcge_pisces/data/models/todo.dart';

class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(paginatedTodosProvider);
    final currentFilter = ref.watch(todoFilterProvider);
    final todoNotifier = ref.read(todoListProvider.notifier);

    void editTodoDialog(BuildContext context, Todo todo) {
      // ... (dialog code remains the same) ...
      final TextEditingController controller = TextEditingController(
        text: todo.title,
      );
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              // Keep constraints
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '修改',
                      style: Theme.of(context).textTheme.titleLarge,
                    ), // Use theme
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: '任务内容',
                      ), // Added label
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end, // Align buttons end
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          // Use ElevatedButton for primary action
                          onPressed: () {
                            final newTitle = controller.text.trim();
                            if (newTitle.isNotEmpty && newTitle != todo.title) {
                              // Use ref.read to call the notifier method
                              ref
                                  .read(todoListProvider.notifier)
                                  .editTodo(todo.id, newTitle);
                            }
                            Navigator.of(context).pop();
                          },
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        const FilterButtons(),
        // Conditional Input based on filter
        if (currentFilter == '今' || currentFilter == '明') const TodoInput(),
        Expanded(
          child:
              todos.isEmpty
                  ? Center(child: Text('没有 "$currentFilter" 的任务')) // Use const
                  : ListView.builder(
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return TodoItem(
                        key: ValueKey(todo.id),
                        todo: todo,
                        onToggle:
                            () => todoNotifier.toggleTodoCompletion(todo.id),
                        onDelete: () => todoNotifier.deleteTodo(todo.id),
                        onMoveToTomorrow:
                            () => todoNotifier.moveTodoToTomorrow(todo.id),
                        onMoveToToday:
                            () => todoNotifier.moveTodToToday(todo.id),
                        onEdit: () => editTodoDialog(context, todo),
                        isYesterday: currentFilter == '昨',
                      );
                    },
                  ),
        ),
        const Padding(
          // Add const
          padding: EdgeInsets.only(bottom: 80.0, top: 10.0),
          child: Pagination(),
        ),
      ],
    );
  }
}
