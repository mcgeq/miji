import 'package:miji/services/api/api_service.dart';
import 'package:miji/data/models/index.dart';

class RemoteTodoSource {
  final ApiService api;

  RemoteTodoSource(this.api);

  Future<List<Todos>> fetchTodos({int page = 1, int pageSize = 20}) async {
    final data = await api.request(
      '/api/todos',
      queryParameters: {'page': page, 'page_size': pageSize},
    );

    final list = _extractListData(data);
    return list ?? [];
  }

  List<Todos>? _extractListData(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final data = raw['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(Todos.fromJson)
          .toList();
    }
    return null;
  }
}