import 'package:miji/data/models/index.dart';
import 'package:miji/services/api/xhttp.dart';

abstract class TodoRepository {
  Future<Todo> fetchTodo(String todoId);
}

class TodoRepositoryImpl implements TodoRepository {
  final XHttp xhttp;

  TodoRepositoryImpl(this.xhttp);

  @override
  Future<Todo> fetchTodo(String todoId) async {
    final result = await xhttp.request('/api/todos/$todoId');
    if (result.success) {
      return Todo.fromJson(result.data as Map<String, dynamic>);
    }
    throw Exception(result.message);
  }
}