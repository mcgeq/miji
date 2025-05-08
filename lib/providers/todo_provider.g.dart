// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$paginatedTodosHash() => r'ced7abf900f6aa9f90b759dee40a3366df9f3709';

/// See also [paginatedTodos].
@ProviderFor(paginatedTodos)
final paginatedTodosProvider = AutoDisposeProvider<List<Todo>>.internal(
  paginatedTodos,
  name: r'paginatedTodosProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$paginatedTodosHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PaginatedTodosRef = AutoDisposeProviderRef<List<Todo>>;
String _$totalTodoPagesHash() => r'575adec8caa8fce4f5fe0ea2c4c09db7dfa6fdb0';

/// See also [totalTodoPages].
@ProviderFor(totalTodoPages)
final totalTodoPagesProvider = AutoDisposeProvider<int>.internal(
  totalTodoPages,
  name: r'totalTodoPagesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$totalTodoPagesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TotalTodoPagesRef = AutoDisposeProviderRef<int>;
String _$todoListHash() => r'1aa1b4a9a9c29b623a6a7afbe1d1d0274844e575';

/// See also [TodoList].
@ProviderFor(TodoList)
final todoListProvider = NotifierProvider<TodoList, List<Todo>>.internal(
  TodoList.new,
  name: r'todoListProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$todoListHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TodoList = Notifier<List<Todo>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
