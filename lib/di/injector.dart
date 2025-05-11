import 'package:get_it/get_it.dart';
import 'package:miji/data/repositories/todo_repository.dart';
import 'package:miji/services/api/api_service.dart';
import 'package:miji/services/api/xhttp.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  getIt.registerSingleton<XHttp>(XHttp.getInstance());
  getIt.registerSingleton<TodoRepository>(
    TodoRepositoryImpl(ApiService(getIt<XHttp>())),
  );
}