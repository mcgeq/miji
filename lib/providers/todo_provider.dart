// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           todo_provider.dart
// Description:    About todo_provider
// Create   Date:  2025-04-12 10:52:09
// Last Modified:  2025-05-09 23:16:09
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
import 'dart:async';
import 'package:hive_flutter/adapters.dart';
import 'package:miji/data/models/enums/status.dart';
import 'package:miji/data/models/enums/priority.dart';
import 'package:miji/data/models/todos/todo_input.dart';
import 'package:miji/data/models/todos/todo_response.dart';
import 'package:miji/services/todo_service.dart';
import 'package:miji/utils/date_time_extensions.dart';
import 'package:miji/utils/xhttp.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/constants/constants.dart';
import 'package:miji/services/logging/logger.dart';
import 'package:miji/services/notifications/notification_service.dart';
import 'package:miji/utils/mguid.dart';

part 'todo_provider.g.dart';

// --- Enums ---

/// 定义待办事项过滤类型
enum TodoFilter {
  yesterday('昨'),
  today('今'),
  tomorrow('明');

  final String value;
  const TodoFilter(this.value);
}

// --- Models ---

/// 定义分页参数
class PaginationParams {
  final int page;
  final int pageSize;

  PaginationParams({required this.page, required this.pageSize});

  factory PaginationParams.fromMap(Map<String, int> map) {
    if (map['page'] == null || map['pageSize'] == null) {
      throw ArgumentError('Page and pageSize must be provided');
    }
    return PaginationParams(page: map['page']!, pageSize: map['pageSize']!);
  }

  @override
  String toString() => 'Page: $page, PageSize: $pageSize';
}

/// 本地待办事项模型（基于 `Hive` 存储）
@HiveType(typeId: 0)
class Todo {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  bool isCompleted;

  @HiveField(3)
  DateTime? completedAt;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime dueDate;

  @HiveField(6)
  Priority priority;

  @HiveField(7)
  String? description;

  @HiveField(8)
  List<String> tags;

  @HiveField(9)
  DateTime? reminder;

  Todo({
    required this.title,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.dueDate,
    this.priority = Priority.medium,
    this.description,
    this.tags = const [],
    required this.id,
    this.reminder,
  });

  void toggleCompletion() {
    isCompleted = !isCompleted;
    completedAt = isCompleted ? DateTime.now() : null;
  }

  void moveToTomorrow() {
    dueDate = DateTime.now()
        .add(const Duration(days: 1))
        .copyWith(hour: 23, minute: 59, second: 59, millisecond: 999);
  }

  void moveToToday() {
    dueDate = DateTime.now().copyWith(
      hour: 23,
      minute: 59,
      second: 59,
      millisecond: 999,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'priority': priority.toString(),
      'description': description,
      'tags': tags,
      'reminder': reminder?.toIso8601String(),
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'],
      completedAt:
          json['completedAt'] != null
              ? DateTime.parse(json['completedAt'])
              : null,
      createdAt: DateTime.parse(json['createdAt']),
      dueDate: DateTime.parse(json['dueDate']),
      priority: Priority.values.firstWhere(
        (e) => e.toString() == json['priority'],
        orElse: () => Priority.medium,
      ),
      description: json['description'],
      tags: List<String>.from(json['tags']),
      reminder:
          json['reminder'] != null ? DateTime.parse(json['reminder']) : null,
    );
  }

  @override
  String toString() => toJson().toString();
}

// --- Providers ---

/// 提供 `XHttp` 实例，用于 HTTP 请求。
@riverpod
XHttp xHttp(Ref ref) => XHttp.getInstance();

/// 提供 `TodoService` 实例，用于执行 todo 相关 API 操作。
@riverpod
TodoService taskService(Ref ref) {
  final xHttp = ref.watch(xHttpProvider);
  return TodoService(xHttp);
}

/// 提供过滤条件的 `StateNotifier`。
@riverpod
class TodoFilterNotifier extends _$TodoFilterNotifier {
  @override
  TodoFilter build() => TodoFilter.today;

  void setFilter(TodoFilter newFilter) {
    state = newFilter;
  }
}

/// 提供分页状态的 `StateNotifier`。
@riverpod
class TodoPageNotifier extends _$TodoPageNotifier {
  @override
  int build() => 1;

  void setPage(int newPage) {
    state = newPage;
  }

  void incrementPage(int totalPages) {
    if (state < totalPages) {
      state++;
    }
  }

  void decrementPage() {
    if (state > 1) {
      state--;
    }
  }

  void goToFirstPage() {
    state = 1;
  }

  void goToLastPage(int totalPages) {
    state = totalPages;
  }
}

/// 提供同步状态的 `StateNotifier`，用于触发同步。
@riverpod
class SyncTriggerNotifier extends _$SyncTriggerNotifier {
  @override
  bool build() => false;

  void triggerSync() {
    state = true;
  }

  void resetSync() {
    state = false;
  }
}

/// 提供创建 todo 的异步操作，接受 `TodoInput` 并返回 `TodoResponse`。
@riverpod
Future<TodoResponse> createTodo(Ref ref, TodoInput todo) async {
  try {
    final service = ref.watch(taskServiceProvider);
    final response = await service.createTodo(todo);
    final todoList = ref.read(todoListProvider.notifier);
    await todoList.syncTodoFromResponse(response);
    return response;
  } catch (e) {
    XHttp.setErrorTitle('Create Todo Error');
    throw Exception('Failed to create todo: $e');
  }
}

/// 提供获取单个 todo 的异步操作，接受 `serialNum` 并返回 `TodoResponse`。
@riverpod
Future<TodoResponse> getTodo(Ref ref, String serialNum) async {
  try {
    if (serialNum.isEmpty) {
      throw ArgumentError('Serial number cannot be empty');
    }
    final service = ref.watch(taskServiceProvider);
    final response = await service.getTodo(serialNum);
    final todoList = ref.read(todoListProvider.notifier);
    await todoList.syncTodoFromResponse(response);
    return response;
  } catch (e) {
    XHttp.setErrorTitle('Get Todo Error');
    throw Exception('Failed to get todo: $e');
  }
}

/// 提供获取 todo 列表的异步操作，接受分页参数并返回 `List<TodoResponse>`。
@riverpod
Future<List<TodoResponse>> todoListFetch(
  Ref ref,
  PaginationParams params,
) async {
  try {
    if (params.page < 1 || params.pageSize < 1) {
      throw ArgumentError('Page and pageSize must be positive integers');
    }
    final service = ref.watch(taskServiceProvider);
    final response = await service.getTodos(params.page, params.pageSize);
    final todoList = ref.read(todoListProvider.notifier);
    await todoList.syncTodosFromResponse(response);
    return response;
  } catch (e) {
    XHttp.setErrorTitle('Get Todos Error');
    throw Exception('Failed to get todo list: $e');
  }
}

/// 管理本地待办事项列表，支持网络同步和本地操作。
@Riverpod(keepAlive: true)
class TodoList extends _$TodoList {
  late Box<Todo> _todoBox;

  @override
  List<Todo> build() {
    _todoBox = Hive.box<Todo>('todos');
    _todoBox.listenable().addListener(_updateState);
    ref.onDispose(() => _todoBox.listenable().removeListener(_updateState));
    ref.listen(syncTriggerNotifierProvider, (previous, next) {
      if (next) {
        _syncFromNetwork().then((_) {
          ref.read(syncTriggerNotifierProvider.notifier).resetSync();
        });
      }
    });
    return _getTodosFromBox();
  }

  // --- 数据获取与同步 ---
  List<Todo> _getTodosFromBox() {
    if (!_todoBox.isOpen) {
      McgLogger.w('TodoList', 'Hive box is closed, attempting to reopen.');
      _todoBox = Hive.box<Todo>('todos');
      if (!_todoBox.isOpen) {
        McgLogger.e('TodoList', 'Failed to open todos box.');
        return [];
      }
    }
    try {
      final todos = _todoBox.values.toList();
      McgLogger.i(
        'TodoList',
        'Loaded todos:\n${todos.map((todo) => todo.toJson()).join('\n')}',
      );
      return todos;
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Error reading todos', e, stackTrace);
      return [];
    }
  }

  Future<void> _syncFromNetwork() async {
    try {
      final params = PaginationParams(page: 1, pageSize: 100);
      await ref.read(todoListFetchProvider(params).future);
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Failed to sync from network', e, stackTrace);
    }
  }

  Future<void> syncTodoFromResponse(TodoResponse response) async {
    try {
      final todo = Todo(
        id: response.serialNum,
        title: response.title,
        createdAt: response.createdAt, // 使用 response.createdAt
        dueDate: response.dueAt,
        reminder: response.reminders.firstOrNull?.remindAt, // 从 reminders 中提取
        isCompleted: response.status == Status.done,
        completedAt: response.completedAt,
        priority: response.priority,
        description: response.description,
        tags: response.tags.map((tag) => tag.core.name).toList(),
      );
      await _todoBox.put(todo.id, todo);
      _updateState();
      McgLogger.i('TodoList', 'Synced todo: ${todo.toJson()}');
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Failed to sync todo', e, stackTrace);
    }
  }

  Future<void> syncTodosFromResponse(List<TodoResponse> responses) async {
    try {
      for (final response in responses) {
        final todo = Todo(
          id: response.serialNum,
          title: response.title,
          createdAt: response.createdAt, // 使用 response.createdAt
          dueDate: response.dueAt,
          reminder: response.reminders.firstOrNull?.remindAt, // 从 reminders 中提取
          isCompleted: response.status == Status.done,
          completedAt: response.completedAt,
          priority: response.priority,
          description: response.description,
          tags: response.tags.map((tag) => tag.core.name).toList(),
        );
        await _todoBox.put(todo.id, todo);
      }
      _updateState();
      McgLogger.i('TodoList', 'Synced ${responses.length} todos');
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Failed to sync todos', e, stackTrace);
    }
  }

  void _updateState() {
    state = _getTodosFromBox();
  }

  // --- 计算属性 ---

  List<Todo> getFilteredTodos() {
    final filter = ref.watch(todoFilterNotifierProvider);
    final todos = state;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 2));
    final tomorrow = today.add(const Duration(days: 1));

    return todos.where((todo) {
        final date = todo.dueDate;
        switch (filter) {
          case TodoFilter.yesterday:
            return date.isBefore(yesterday);
          case TodoFilter.today:
            return today.isWithinDays(date, -2);
          case TodoFilter.tomorrow:
            return date.isSameDay(tomorrow);
        }
      }).toList()
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        return b.dueDate.compareTo(a.dueDate);
      });
  }

  List<Todo> getPaginatedTodos() {
    final page = ref.watch(todoPageNotifierProvider);
    final filtered = getFilteredTodos();

    final startIndex = (page - 1) * AppConstants.todosPerPage;
    final endIndex = (startIndex + AppConstants.todosPerPage).clamp(
      0,
      filtered.length,
    );

    return startIndex >= filtered.length
        ? []
        : filtered.sublist(startIndex, endIndex);
  }

  int getTotalPages() {
    final count = getFilteredTodos().length;
    return count == 0 ? 1 : (count / AppConstants.todosPerPage).ceil();
  }

  // --- 操作方法 ---

  Future<void> addTodo(
    String title, {
    DateTime? reminder,
    DateTime? dueDate,
  }) async {
    try {
      if (title.trim().isEmpty) {
        throw ArgumentError('Title cannot be empty');
      }

      final now = DateTime.now();
      final defaultDueDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final todo = Todo(
        id: MgUUID.generate(),
        title: title.trim(),
        createdAt: now,
        reminder: reminder,
        dueDate: dueDate ?? defaultDueDate,
      );

      await _todoBox.put(todo.id, todo);
      _updateState();

      if (reminder != null && reminder.isAfter(now)) {
        await _scheduleNotification(todo);
      }

      final todoInput = TodoInput(
        title: todo.title,
        description: '',
        dueAt: todo.dueDate,
        priority: Priority.medium,
        status: todo.isCompleted ? Status.done : Status.todo,
        progress: 0,
      );
      await ref.read(createTodoProvider(todoInput).future);
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Failed to add todo', e, stackTrace);
      rethrow;
    }
  }

  Future<void> editTodo(String todoId, String newTitle) async {
    try {
      final todo = _todoBox.get(todoId);
      if (todo == null) {
        McgLogger.w('TodoList', 'Todo not found: $todoId');
        return;
      }
      if (newTitle.trim().isEmpty) {
        throw ArgumentError('New title cannot be empty');
      }

      todo.title = newTitle.trim();
      await _todoBox.put(todoId, todo);
      _updateState();

      // 同步到网络（需 TaskService 支持 updateTodo）
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Failed to edit todo', e, stackTrace);
      rethrow;
    }
  }

  Future<void> toggleTodoCompletion(String todoId) async {
    try {
      final todo = _todoBox.get(todoId);
      if (todo == null) {
        McgLogger.w('TodoList', 'Todo not found: $todoId');
        return;
      }

      final wasCompleted = todo.isCompleted;
      final originalReminder = todo.reminder;

      todo.toggleCompletion();
      await _todoBox.put(todoId, todo);
      _updateState();

      if (todo.isCompleted && originalReminder != null) {
        await NotificationService.cancelNotification(todo.id.hashCode);
      } else if (!todo.isCompleted &&
          wasCompleted &&
          originalReminder != null &&
          originalReminder.isAfter(DateTime.now())) {
        await _scheduleNotification(todo);
      }

      // 同步到网络（需 TaskService 支持 updateTodo）
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Failed to toggle completion', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteTodo(String todoId) async {
    try {
      final todo = _todoBox.get(todoId);
      if (todo == null) {
        McgLogger.w('TodoList', 'Todo not found: $todoId');
        return;
      }

      if (todo.reminder != null) {
        await NotificationService.cancelNotification(todo.id.hashCode);
      }

      await _todoBox.delete(todoId);
      _updateState();

      await _adjustPaginationAfterDelete();
      // 同步到网络（需 TaskService 支持 deleteTodo）
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Failed to delete todo', e, stackTrace);
      rethrow;
    }
  }

  Future<void> moveToTomorrow(String todoId) async {
    try {
      final todo = _todoBox.get(todoId);
      if (todo == null) {
        McgLogger.w('TodoList', 'Todo not found: $todoId');
        return;
      }

      todo.moveToTomorrow();
      await _todoBox.put(todoId, todo);
      _updateState();

      // 同步到网络（需 TaskService 支持 updateTodo）
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Failed to move to tomorrow', e, stackTrace);
      rethrow;
    }
  }

  Future<void> moveToToday(String todoId) async {
    try {
      final todo = _todoBox.get(todoId);
      if (todo == null) {
        McgLogger.w('TodoList', 'Todo not found: $todoId');
        return;
      }

      todo.moveToToday();
      await _todoBox.put(todoId, todo);
      _updateState();

      // 同步到网络（需 TaskService 支持 updateTodo）
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Failed to move to today', e, stackTrace);
      rethrow;
    }
  }

  // --- 辅助方法 ---

  Future<void> _scheduleNotification(Todo todo) async {
    try {
      await NotificationService.scheduleNotification(
        id: todo.id.hashCode,
        title: 'Todo Reminder',
        body: 'Task: ${todo.title}',
        scheduledDate: todo.reminder!,
      );
      McgLogger.i('TodoList', 'Scheduled notification for: ${todo.id}');
    } catch (e, stackTrace) {
      McgLogger.e('TodoList', 'Failed to schedule notification', e, stackTrace);
    }
  }

  Future<void> _adjustPaginationAfterDelete() async {
    await Future.microtask(() {
      final totalPages = getTotalPages();
      final currentPage = ref.read(todoPageNotifierProvider);
      if (currentPage > totalPages && totalPages > 0) {
        ref.read(todoPageNotifierProvider.notifier).setPage(totalPages);
      } else if (currentPage > 1 && getPaginatedTodos().isEmpty) {
        ref.read(todoPageNotifierProvider.notifier).setPage(currentPage - 1);
      } else if (totalPages == 1 && getFilteredTodos().isEmpty) {
        ref.read(todoPageNotifierProvider.notifier).setPage(1);
      }
    });
  }

  // --- 分页操作 ---

  void nextPage() {
    ref.read(todoPageNotifierProvider.notifier).incrementPage(getTotalPages());
  }

  void previousPage() {
    ref.read(todoPageNotifierProvider.notifier).decrementPage();
  }

  void firstPage() {
    ref.read(todoPageNotifierProvider.notifier).goToFirstPage();
  }

  void lastPage() {
    ref.read(todoPageNotifierProvider.notifier).goToLastPage(getTotalPages());
  }
}

// Helper provider to get paginated todos
@riverpod
List<Todo> paginatedTodos(Ref ref) {
  ref.watch(todoListProvider);
  ref.watch(todoFilterNotifierProvider);
  ref.watch(todoPageNotifierProvider);
  return ref.read(todoListProvider.notifier).getPaginatedTodos();
}

// Helper provider for total pages
@riverpod
int totalTodoPages(Ref ref) {
  ref.watch(todoListProvider);
  ref.watch(todoFilterNotifierProvider);
  return ref.read(todoListProvider.notifier).getTotalPages();
}
