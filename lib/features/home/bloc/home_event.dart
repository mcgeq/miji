abstract class HomeEvent {}

class LoadTodos extends HomeEvent {
  final int page;

  LoadTodos({required this.page});
}

class AddTodo extends HomeEvent {
  final String title;

  AddTodo(this.title);
}

class DeleteTodo extends HomeEvent {
  final int index;

  DeleteTodo(this.index);
}