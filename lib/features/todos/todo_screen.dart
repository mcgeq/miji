// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           todo_screen.dart
// Description:    About Todo Screen
// Create   Date:  2025-04-12 10:54:38
// Last Modified:  2025-05-09 22:23:07
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/features/todos/widgets/filter_buttons.dart';

import 'package:miji/features/todos/widgets/pagination.dart';

import 'package:miji/features/todos/widgets/todo_input.dart';

import 'package:miji/features/todos/widgets/todo_item.dart';
import 'package:miji/providers/todo_provider.dart';
import 'package:miji/providers/todo_filter_provider.dart';

// 移除重复的 Todo 导入，使用 todo_provider.dart 中的 Todo
// import 'package:miji/data/models/todo.dart';

class TodoScreen extends ConsumerWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(paginatedTodosProvider);
    final currentFilter = ref.watch(todoFilterProvider);
    final todoNotifier = ref.read(todoListProvider.notifier);

    void editTodoDialog(BuildContext context, Todo todo) {
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
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('修改', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: '任务内容'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final newTitle = controller.text.trim();
                            if (newTitle.isNotEmpty && newTitle != todo.title) {
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
                  ? Center(child: Text('没有 "$currentFilter" 的任务'))
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
                            () => todoNotifier.moveToTomorrow(todo.id), // 修正方法名
                        onMoveToToday:
                            () => todoNotifier.moveToToday(todo.id), // 修正方法名
                        onEdit: () => editTodoDialog(context, todo),
                        isYesterday: currentFilter == '昨',
                      );
                    },
                  ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 80.0, top: 10.0),
          child: Pagination(),
        ),
      ],
    );
  }
}