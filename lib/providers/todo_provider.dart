// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           todo_provider.dart
// Description:    About todo_provider
// Create   Date:  2025-04-12 10:52:09
// Last Modified:  2025-04-12 11:00:51
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
import 'dart:async';
import 'package:hive_flutter/adapters.dart';
import 'package:miji/utils/date_time_extensions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/constants/constants.dart';
import 'package:miji/data/models/todo.dart';
import 'package:miji/services/logging/logger.dart';
import 'package:miji/services/notifications/notification_service.dart';
import 'package:miji/utils/mguid.dart';
import 'package:miji/providers/todo_filter_provider.dart';
import 'package:miji/providers/todo_page_provider.dart';

part 'todo_provider.g.dart';

@Riverpod(keepAlive: true)
class TodoList extends _$TodoList {
  late Box<Todo> _todoBox;

  @override
  List<Todo> build() {
    _todoBox = Hive.box<Todo>('todos');
    // 自动监听 Hive box 中的变动
    _todoBox.listenable().addListener(_updateState);

    // 清理监听器
    ref.onDispose(() {
      _todoBox.listenable().removeListener(_updateState);
    });
    return _getTodosFromBox();
  }

  List<Todo> _getTodosFromBox() {
    if (!_todoBox.isOpen) {
      McgLogger.w('TodoList', 'Attempted to read from closed Hive box.');
      return [];
    }
    try {
      McgLogger.i(
        'TodoList',
        _todoBox.values.map((todo) => todo.toJson()).join('\n'),
      );
      return _todoBox.values.toList();
    } catch (e, stackTrace) {
      McgLogger.e(
        'TodoList',
        'Error reading todos from Hive box',
        e,
        stackTrace,
      );
      return [];
    }
  }

  // --- Computed State ---

  List<Todo> getFilteredTodos() {
    final currentFilter = ref.watch(todoFilterProvider);
    final allTodos = state;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 2));
    final tomorrow = today.add(const Duration(days: 1));

    final List<Todo> result =
        allTodos.where((todo) {
          final date = todo.dueDate;
          bool include = false; // Flag to check if included

          if (currentFilter == '昨') {
            include = date.isBefore(yesterday);
          } else if (currentFilter == '今') {
            return today.isWithinDays(date, -2);
          } else if (currentFilter == '明') {
            return date.isSameDay(tomorrow);
          }
          return include; // Return the flag
        }).toList();
    // Sorting logic remains the same
    result.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return b.dueDate.compareTo(a.dueDate);
    });

    return result;
  }

  List<Todo> getPaginatedTodos() {
    final currentPage = ref.watch(todoPageProvider);
    final filtered = getFilteredTodos();

    const int todosPerPage = AppConstants.todosPerPage;
    final startIndex = (currentPage - 1) * todosPerPage;
    final endIndex =
        (startIndex + todosPerPage > filtered.length)
            ? filtered.length
            : startIndex + todosPerPage;

    if (startIndex >= filtered.length || startIndex < 0) {
      return [];
    }

    return filtered.sublist(startIndex, endIndex);
  }

  int getTotalPages() {
    final filteredCount = getFilteredTodos().length;
    if (filteredCount == 0) return 1;
    return (filteredCount / AppConstants.todosPerPage).ceil();
  }

  // --- Actions ---
  void _updateState() {
    state = _getTodosFromBox();
  }

  Future<void> addTodo(
    String title, {
    DateTime? reminder,
    DateTime? dueDate,
  }) async {
    final now = DateTime.now();
    final defaultDueDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final todo = Todo(
      id: MgUUID.generate(),
      title: title,
      createdAt: now,
      reminder: reminder,
      dueDate: dueDate ?? defaultDueDate,
    );

    await _todoBox.put(todo.id, todo);
    _updateState();

    McgLogger.i('Todo', 'Added: ${todo.toJson()}');
    if (reminder != null && reminder.isAfter(DateTime.now())) {
      await NotificationService.scheduleNotification(
        id: todo.id.hashCode,
        title: 'Todo Reminder',
        body: 'Task: ${todo.title}',
        scheduledDate: reminder,
      );
    }
  }

  Future<void> editTodo(String todoId, String newTitle) async {
    final todo = _todoBox.get(todoId);
    if (todo == null) return;
    todo.title = newTitle;
    await _todoBox.put(todoId, todo);
    _updateState();
    McgLogger.i('Todo', 'Edited: ${todo.toJson()}');
  }

  Future<void> toggleTodoCompletion(String todoId) async {
    final todo = _todoBox.get(todoId);
    if (todo == null) return;

    final bool wasCompleted = todo.isCompleted;
    final DateTime? originalReminder = todo.reminder;

    todo.toggleCompletion();
    await _todoBox.put(todoId, todo);
    _updateState();

    McgLogger.i('Todo', 'Toggled: ${todo.toJson()}');

    if (todo.isCompleted && originalReminder != null) {
      await NotificationService.cancelNotification(todo.id.hashCode);
    } else if (!todo.isCompleted &&
        wasCompleted &&
        originalReminder != null &&
        originalReminder.isAfter(DateTime.now())) {
      await NotificationService.scheduleNotification(
        id: todo.id.hashCode,
        title: 'Todo Reminder',
        body: 'Task: ${todo.title}',
        scheduledDate: originalReminder,
      );
    }
  }

  // Inside the TodoList class in lib/providers/todo_provider.dart

  Future<void> deleteTodo(String todoId) async {
    final todo = _todoBox.get(todoId);
    if (todo == null) return;

    if (todo.reminder != null) {
      await NotificationService.cancelNotification(todo.id.hashCode);
    }
    await _todoBox.delete(todoId);
    _updateState(); // Manually update state
    McgLogger.i('Todo', 'Deleted ID: $todoId');

    // Allow state update before pagination check
    await Future.microtask(() {
      final totalPages = getTotalPages();
      final currentPage = ref.read(todoPageProvider);
      if (currentPage > totalPages && totalPages > 0) {
        ref.read(todoPageProvider.notifier).setPage(totalPages);
      } else if (currentPage > 1 && getPaginatedTodos().isEmpty) {
        // Check if current *paginated* list is empty
        // Go to previous page if current page becomes empty (and not page 1)
        ref.read(todoPageProvider.notifier).setPage(currentPage - 1);
      } else if (totalPages == 1 && getFilteredTodos().isEmpty) {
        // Check *filtered* list when resetting to page 1
        // If totalPages is now 1 (or 0 effectively) AND the filtered list is
        // empty, ensure page is 1.
        ref.read(todoPageProvider.notifier).setPage(1);
      }
    });
  }

  Future<void> moveTodoToTomorrow(String todoId) async {
    final todo = _todoBox.get(todoId);
    if (todo == null) return;
    todo.moveToTomorrow();
    await _todoBox.put(todoId, todo);
    _updateState();
    McgLogger.i('Todo', 'Moved to tomorrow: ${todo.toJson()}');
  }

  Future<void> moveTodToToday(String todoId) async {
    final todo = _todoBox.get(todoId);
    if (todo == null) return;
    todo.moveToToday();
    await _todoBox.put(todoId, todo);
    _updateState();
    McgLogger.i('Todo', 'Moved to today: ${todo.toJson()}');
  }
}

// Helper provider to get paginated todos
@riverpod
List<Todo> paginatedTodos(Ref ref) {
  // Use Ref type from flutter_riverpod
  ref.watch(todoListProvider);
  ref.watch(todoFilterProvider);
  ref.watch(todoPageProvider);
  return ref.read(todoListProvider.notifier).getPaginatedTodos();
}

// Helper provider for total pages
@riverpod
int totalTodoPages(Ref ref) {
  // Use Ref type from flutter_riverpod
  ref.watch(todoListProvider);
  ref.watch(todoFilterProvider);
  return ref.read(todoListProvider.notifier).getTotalPages();
}
