import 'package:flutter/foundation.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:mcge_pisces/constants/constants.dart';
import 'package:mcge_pisces/models/todo.dart';
import 'package:mcge_pisces/utils/date_time_extensions.dart';
import 'package:mcge_pisces/utils/logger.dart';
import 'package:mcge_pisces/utils/notification_service.dart';
import 'package:mcge_pisces/utils/mguid.dart';

class TodoProvider extends ChangeNotifier {
  List<Todo> _todos = [];
  int _currentPage = 1;
  String _filter = '今';
  late Box<Todo> _todoBox;

  List<Todo> get todos => _todos;
  int get currentPage => _currentPage;
  String get filter => _filter;

  TodoProvider() {
    _initHive();
  }

  Future<void> _initHive() async {
    _todoBox = await Hive.openBox<Todo>('todos');
    _todoBox.listenable().addListener(_onBoxChanged);
    _todos = _todoBox.values.toList();
    notifyListeners();
  }

  void _onBoxChanged() {
    _todos = _todoBox.values.toList();
    notifyListeners();
  }

  List<Todo> get filteredTodos {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    final List<Todo> result =
        _todos.where((todo) {
          final date = todo.completedAt ?? todo.createdAt;
          if (_filter == '昨') {
            return date.isSameDay(yesterday);
          } else if (_filter == '今') {
            return date.isSameDay(today);
          } else if (_filter == '明') {
            return date.isSameDay(tomorrow);
          }
          return false;
        }).toList();
    // 未完成任务按创建时间降序排列，已完成任务按创建时间升序排列
    result.sort((a, b) {
      if (a.isCompleted == b.isCompleted) {
        // 如果完成状态相同，按创建时间排序
        return a.isCompleted
            ? a.createdAt.compareTo(b.createdAt) // 已完成任务按创建时间升序排列
            : b.createdAt.compareTo(a.createdAt); // 未完成任务按创建时间降序排列
      } else {
        return a.isCompleted ? 1 : -1; // 已完成任务排后面
      }
    });
    return result;
  }

  List<Todo> get paginatedTodos {
    const int todosPerPage = AppConstants.todosPerPage;
    final startIndex = (_currentPage - 1) * todosPerPage;
    final endIndex = startIndex + todosPerPage;
    return filteredTodos
        .asMap()
        .entries
        .where((entry) => entry.key >= startIndex && entry.key < endIndex)
        .map((entry) => entry.value)
        .toList();
  }

  int get totalPages =>
      (filteredTodos.length / AppConstants.todosPerPage).ceil();

  Future<void> addTodo(String title, {DateTime? reminder}) async {
    final todo = Todo(
      id: MgUUID.generate(),
      title: title,
      createdAt: DateTime.now(),
      reminder: reminder,
    );
    _todos.add(todo);
    // await _todoBox.add(todo);
    await _todoBox.put(todo.id, todo);
    McgLogger.i('Todo', todo.toJson().toString());
    if (reminder != null) {
      await NotificationService.scheduleNotification(
        id: todo.id.hashCode,
        title: 'Todo Reminder',
        body: 'Time to complete: ${todo.title}',
        scheduledDate: reminder,
      );
    }
    notifyListeners();
  }

  Future<void> toggleTodoCompletion(int index) async {
    final todo = _todos[index];
    todo.toggleCompletion();
    await _todoBox.putAt(index, todo);
    if (todo.isCompleted && todo.reminder != null) {
      await NotificationService.cancelNotification(todo.id.hashCode);
    }
    notifyListeners();
  }

  Future<void> deleteTodo(String todoId) async {
    final todo = _todoBox.get(todoId); // 先检查是否存在
    if (todo == null) return;

    if (todo.reminder != null) {
      await NotificationService.cancelNotification(todo.id.hashCode);
    }
    await _todoBox.delete(todoId);
    _todos.removeWhere((t) => t.id == todoId);
    notifyListeners();
  }

  void moveTodoToTomorrow(String todoId) {
    final index = _todos.indexWhere((todo) => todo.id == todoId);
    if (index == -1) return;

    final todo = _todos[index];
    todo.moveToTomorrow();
    notifyListeners(); // 更新 UI
  }

  void setFilter(String filter) {
    _filter = filter;
    _currentPage = 1;
    notifyListeners();
  }

  void setPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }
}
