import 'package:miji/data/models/index.dart';
import 'package:miji/services/api/xhttp.dart';
import 'package:miji/services/logging/miji_logging.dart';

abstract class TodoRepository {
  Future<Todos> fetchTodo(String todoId);
}

class TodoRepositoryImpl implements TodoRepository {
  final XHttp xhttp;

  TodoRepositoryImpl(this.xhttp);

  @override
  Future<Todos> fetchTodo(String todoId) async {
    try {
      final result = await xhttp.request('/api/todos/$todoId');

      if (!result.success) {
        McgLogger.e('TodoRepository', 'Request failed: ${result.message}');
        return Todos.empty();
      }

      final nestedData = _extractNestedData(result.data);
      if (nestedData == null) {
        McgLogger.e(
          'TodoRepository',
          'Invalid response structure: ${result.data}',
        );
        return Todos.empty();
      }

      return Todos.fromJson(nestedData);
    } catch (e) {
      McgLogger.e('TodoRepository', 'Exception: $e');
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