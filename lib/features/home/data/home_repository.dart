import 'package:miji/data/repositories/todo_repository.dart';
import 'package:miji/di/injector.dart';

class HomeRepository {
  final TodoRepository _todoRepository = getIt<TodoRepository>();
  final List<String> _mockTodos = [];

  Future<List<String>> getTodos({required int page, required int limit}) async {
    try {
      // Simulate pagination using TodoRepository
      final todo = await _todoRepository.fetchTodo(
        '20250426091357948402500786969162',
      );
      final start = (page - 1) * limit;
      final end = start + limit;
      final mockData = [
        todo.title,
        ...todo.projects.map((p) => p.name),
        ..._mockTodos,
      ];
      return mockData.length > start
          ? mockData.sublist(start, end.clamp(0, mockData.length))
          : [];
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addTodo(String title) async {
    // Simulate adding to API
    _mockTodos.add(title);
  }

  Future<void> deleteTodo(int index) async {
    // Simulate deleting from API
    if (index < _mockTodos.length) {
      _mockTodos.removeAt(index);
    }
  }
}