import 'package:flutter/material.dart';
import 'package:mcge_pisces/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:mcge_pisces/providers/todo_provider.dart';
import 'package:mcge_pisces/widgets/todo_input.dart';
import 'package:mcge_pisces/widgets/filter_buttons.dart';
import 'package:mcge_pisces/widgets/todo_item.dart';
import 'package:mcge_pisces/widgets/pagination.dart';

class TodoScreen extends StatelessWidget {
  const TodoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final todoProvider = Provider.of<TodoProvider>(context);
    final todos = todoProvider.paginatedTodos;
    final currentFilter = todoProvider.filter;

    // 编辑任务对话框
    void editTodoDialog(
      BuildContext context,
      String todoId,
      String currentTitle,
    ) {
      final TextEditingController controller = TextEditingController(
        text: currentTitle,
      );
      showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 400, // 设置固定宽度
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '修改',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      maxLines: null, // 允许多行输入
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            final newTitle = controller.text.trim();
                            if (newTitle.isNotEmpty) {
                              // 更新任务
                              context.read<TodoProvider>().editTodo(
                                todoId,
                                newTitle,
                              );
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

    return Scaffold(
      body: Column(
        children: [
          const FilterButtons(),
          if (currentFilter == '今' || currentFilter == '明') const TodoInput(),
          Expanded(
            child: ListView.builder(
              itemCount: todos.length,
              itemBuilder: (context, index) {
                final todo = todos[index];
                final globalIndex =
                    (todoProvider.currentPage - 1) * AppConstants.todosPerPage +
                    index;
                return TodoItem(
                  todo: todo,
                  index: globalIndex,
                  onToggle: () => todoProvider.toggleTodoCompletion(todo.id),
                  onDelete: () => todoProvider.deleteTodo(todo.id),
                  onMoveToTomorrow:
                      () => todoProvider.moveTodoToTomorrow(todo.id),
                  onMoveToToday: () => todoProvider.moveTodToToday(todo.id),
                  onEdit: () => editTodoDialog(context, todo.id, todo.title),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 60),
            child: Pagination(),
          ),
        ],
      ),
    );
  }
}
