import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:miji/features/home/bloc/home_event.dart';
import 'package:miji/features/home/bloc/home_state.dart';
import 'package:miji/features/home/data/home_repository.dart';
import 'package:miji/services/logging/miji_logging.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeRepository repository;
  static const int _pageSize = 5;

  HomeBloc(this.repository) : super(HomeState()) {
    on<LoadTodos>(_onLoadTodos);
    on<AddTodo>(_onAddTodo);
    on<DeleteTodo>(_onDeleteTodo);
  }

  Future<void> _onLoadTodos(LoadTodos event, Emitter<HomeState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final todos = await repository.getTodos(
        page: event.page,
        limit: _pageSize,
      );
      final newTodos = event.page == 1 ? todos : [...state.todos, ...todos];
      emit(
        state.copyWith(
          isLoading: false,
          todos: newTodos,
          hasMore: todos.length == _pageSize,
          currentPage: event.page,
        ),
      );
    } catch (e) {
      McgLogger.e('HomeBloc', 'Error loading todos: $e');
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAddTodo(AddTodo event, Emitter<HomeState> emit) async {
    try {
      await repository.addTodo(event.title);
      final newTodos = [...state.todos, event.title];
      emit(state.copyWith(todos: newTodos));
    } catch (e) {
      McgLogger.e('HomeBloc', 'Error adding todo: $e');
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteTodo(DeleteTodo event, Emitter<HomeState> emit) async {
    try {
      await repository.deleteTodo(event.index);
      final newTodos = [...state.todos];
      newTodos.removeAt(event.index);
      emit(state.copyWith(todos: newTodos));
    } catch (e) {
      McgLogger.e('HomeBloc', 'Error deleting todo: $e');
      emit(state.copyWith(error: e.toString()));
    }
  }
}