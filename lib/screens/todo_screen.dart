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
