import 'package:miji/data/models/index.dart';
import 'package:miji/data/sources/cache/todo_cache.dart';
import 'package:miji/data/sources/local/todo_local.dart';
import 'package:miji/data/sources/remote/todo_remote.dart';
import 'package:miji/services/api/api_service.dart';
import 'package:miji/services/logging/miji_logging.dart';

abstract class TodoRepository {
  Future<Todos> fetchTodo(String todoId);
  Future<List<Todos>> fetchTodos({int page = 1, int pageSize = 20});
  Future<Todos> addTodo(Todos todo);
  Future<Todos> updateTodo(String serialNum, Todos todo);
  Future<Todos> deleteTodo(String serialNum);
}

class TodoRepositoryImpl implements TodoRepository {
  final ApiService apiService;
  final RemoteTodoSource remote;
  final CacheTodoSource cache;
  final LocalTodoSource local;

  TodoRepositoryImpl(this.apiService)
    : remote = RemoteTodoSource(apiService),
      cache = CacheTodoSource(),
      local = LocalTodoSource();

  @override
  Future<Todos> fetchTodo(String todoId) async {
    try {
      final data = await apiService.request('/api/todos/$todoId');

      final nestedData = _extractNestedData(data);
      if (nestedData == null) {
        McgLogger.e('TodoRepository', 'Invalid response structure: $data');
        return Todos.empty();
      }

      return Todos.fromJson(nestedData);
    } catch (e) {
      McgLogger.e('TodoRepository', 'Exception: $e');
      return Todos.empty();
    }
  }

  @override
  Future<List<Todos>> fetchTodos({int page = 1, int pageSize = 20}) async {
    try {
      // Step 1: Try to fetch from remote (API)
      final remoteTodos = await remote.fetchTodos(
        page: page,
        pageSize: pageSize,
      );
      if (remoteTodos.isNotEmpty) {
        // Cache the result if fetched from remote
        await cache.saveCache('todos', remoteTodos);
        return remoteTodos;
      }

      // Step 2: If no data from remote, try fetching from cache
      final cacheTodos = cache.getCache('todos');
      if (cacheTodos != null &&
          cacheTodos is List<Todos> &&
          cacheTodos.isNotEmpty) {
        return cacheTodos;
      }

      // Step 3: If no data from cache, fallback to local storage
      final localTodos = local.getCache('todos');
      if (localTodos != null &&
          localTodos is List<Todos> &&
          localTodos.isNotEmpty) {
        return localTodos;
      }

      // Return empty list if no data found in all sources
      return [];
    } catch (e) {
      McgLogger.e('TodoRepository', 'Exception in fetchTodos: $e');
      return [];
    }
  }

  @override
  Future<Todos> addTodo(Todos todo) async {
    try {
      final data = await apiService.request(
        '/api/todos',
        method: 'POST',
        data: todo.toJson(),
      );

      final nestedData = _extractNestedData(data);
      return nestedData != null ? Todos.fromJson(nestedData) : Todos.empty();
    } catch (e) {
      McgLogger.e('TodoRepository', 'Exception in addTodo: $e');
      return Todos.empty();
    }
  }

  @override
  Future<Todos> updateTodo(String serialNum, Todos todo) async {
    try {
      final data = await apiService.request(
        '/api/todos/$serialNum',
        method: 'PUT',
        data: todo.toJson(),
      );

      final nestedData = _extractNestedData(data);
      return nestedData != null ? Todos.fromJson(nestedData) : Todos.empty();
    } catch (e) {
      McgLogger.e('TodoRepository', 'Exception in updateTodo: $e');
      return Todos.empty();
    }
  }

  @override
  Future<Todos> deleteTodo(String serialNum) async {
    try {
      final data = await apiService.request(
        '/api/todos/$serialNum',
        method: 'DELETE',
      );

      final nestedData = _extractNestedData(data);
      return nestedData != null ? Todos.fromJson(nestedData) : Todos.empty();
    } catch (e) {
      McgLogger.e('TodoRepository', 'Exception in deleteTodo: $e');
      return Todos.empty();
    }
  }

  Map<String, dynamic>? _extractNestedData(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    final data = raw['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }
}
