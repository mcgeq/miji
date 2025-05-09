import 'package:miji/data/models/todos/todo_input.dart';
import 'package:miji/data/models/todos/todo_response.dart';
import 'package:miji/utils/xhttp.dart';

class TodoService {
  final XHttp _http;
  TodoService(this._http);

  /// Creates a new todo
  Future<TodoResponse> createTodo(TodoInput todo) async {
    final error = todo.validate();
    if (error != null) throw Exception('Validation failed: $error');

    final response = await _http.request(
      '/todos',
      method: XHttp.post,
      data: todo.toJson(),
      resultDialogConfig: {
        'type': XHttp.dialogTypeToast,
        'successMsg': 'Todo created successfully',
        'errorMsg': 'Failed to create todo',
      },
      msg: 'Creating todo...',
    );
    return TodoResponse.fromJson(response.data);
  }

  Future<TodoResponse> getTodo(String serialNum) async {
    final response = await _http.request(
      '/todos/$serialNum',
      method: XHttp.get,
      resultDialogConfig: {
        'type': XHttp.dialogTypeToast,
        'successMsg': 'Todo fetched successfully',
        'errorMsg': 'Failed to fetch todo',
      },
      msg: 'Fetching todo...',
    );
    return TodoResponse.fromJson(response.data);
  }

  /// Gets a paginated list of todos.
  Future<List<TodoResponse>> getTodos(int page, int pageSize) async {
    final response = await _http.request(
      '/todos',
      method: XHttp.get,
      queryParameters: {'page': page, 'page_size': pageSize},
      resultDialogConfig: {
        'type': XHttp.dialogTypeToast,
        'successMsg': 'Todos fetched successfully',
        'errorMsg': 'Failed to fetch todos',
      },
      msg: 'Fetching todos...',
    );

    final List<dynamic> dataList = response.data;
    return dataList.map((json) => TodoResponse.fromJson(json)).toList();
  }
}
