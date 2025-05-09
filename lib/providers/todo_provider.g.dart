// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_provider.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TodoAdapter extends TypeAdapter<Todo> {
  @override
  final int typeId = 0;

  @override
  Todo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Todo(
      title: fields[1] as String,
      isCompleted: fields[2] as bool,
      completedAt: fields[3] as DateTime?,
      createdAt: fields[4] as DateTime,
      dueDate: fields[5] as DateTime,
      priority: fields[6] as Priority,
      description: fields[7] as String?,
      tags: (fields[8] as List).cast<String>(),
      id: fields[0] as String,
      reminder: fields[9] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Todo obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.isCompleted)
      ..writeByte(3)
      ..write(obj.completedAt)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.dueDate)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.description)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.reminder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$xHttpHash() => r'dd7f2483d5a9837a9be990a6cb5f6c5e25cd5722';

/// 提供 `XHttp` 实例，用于 HTTP 请求。
///
/// Copied from [xHttp].
@ProviderFor(xHttp)
final xHttpProvider = AutoDisposeProvider<XHttp>.internal(
  xHttp,
  name: r'xHttpProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$xHttpHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef XHttpRef = AutoDisposeProviderRef<XHttp>;
String _$taskServiceHash() => r'4cdd4b094ff93e72f3adb361feb19f0445855d84';

/// 提供 `TodoService` 实例，用于执行 todo 相关 API 操作。
///
/// Copied from [taskService].
@ProviderFor(taskService)
final taskServiceProvider = AutoDisposeProvider<TodoService>.internal(
  taskService,
  name: r'taskServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$taskServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TaskServiceRef = AutoDisposeProviderRef<TodoService>;
String _$createTodoHash() => r'217cdae4150a036787c9b4823a6dfdc6c7f084cb';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 提供创建 todo 的异步操作，接受 `TodoInput` 并返回 `TodoResponse`。
///
/// Copied from [createTodo].
@ProviderFor(createTodo)
const createTodoProvider = CreateTodoFamily();

/// 提供创建 todo 的异步操作，接受 `TodoInput` 并返回 `TodoResponse`。
///
/// Copied from [createTodo].
class CreateTodoFamily extends Family<AsyncValue<TodoResponse>> {
  /// 提供创建 todo 的异步操作，接受 `TodoInput` 并返回 `TodoResponse`。
  ///
  /// Copied from [createTodo].
  const CreateTodoFamily();

  /// 提供创建 todo 的异步操作，接受 `TodoInput` 并返回 `TodoResponse`。
  ///
  /// Copied from [createTodo].
  CreateTodoProvider call(
    TodoInput todo,
  ) {
    return CreateTodoProvider(
      todo,
    );
  }

  @override
  CreateTodoProvider getProviderOverride(
    covariant CreateTodoProvider provider,
  ) {
    return call(
      provider.todo,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'createTodoProvider';
}

/// 提供创建 todo 的异步操作，接受 `TodoInput` 并返回 `TodoResponse`。
///
/// Copied from [createTodo].
class CreateTodoProvider extends AutoDisposeFutureProvider<TodoResponse> {
  /// 提供创建 todo 的异步操作，接受 `TodoInput` 并返回 `TodoResponse`。
  ///
  /// Copied from [createTodo].
  CreateTodoProvider(
    TodoInput todo,
  ) : this._internal(
          (ref) => createTodo(
            ref as CreateTodoRef,
            todo,
          ),
          from: createTodoProvider,
          name: r'createTodoProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$createTodoHash,
          dependencies: CreateTodoFamily._dependencies,
          allTransitiveDependencies:
              CreateTodoFamily._allTransitiveDependencies,
          todo: todo,
        );

  CreateTodoProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.todo,
  }) : super.internal();

  final TodoInput todo;

  @override
  Override overrideWith(
    FutureOr<TodoResponse> Function(CreateTodoRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: CreateTodoProvider._internal(
        (ref) => create(ref as CreateTodoRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        todo: todo,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<TodoResponse> createElement() {
    return _CreateTodoProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CreateTodoProvider && other.todo == todo;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, todo.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CreateTodoRef on AutoDisposeFutureProviderRef<TodoResponse> {
  /// The parameter `todo` of this provider.
  TodoInput get todo;
}

class _CreateTodoProviderElement
    extends AutoDisposeFutureProviderElement<TodoResponse> with CreateTodoRef {
  _CreateTodoProviderElement(super.provider);

  @override
  TodoInput get todo => (origin as CreateTodoProvider).todo;
}

String _$getTodoHash() => r'd68f02b9c689beb770490114b37ce5ddec254866';

/// 提供获取单个 todo 的异步操作，接受 `serialNum` 并返回 `TodoResponse`。
///
/// Copied from [getTodo].
@ProviderFor(getTodo)
const getTodoProvider = GetTodoFamily();

/// 提供获取单个 todo 的异步操作，接受 `serialNum` 并返回 `TodoResponse`。
///
/// Copied from [getTodo].
class GetTodoFamily extends Family<AsyncValue<TodoResponse>> {
  /// 提供获取单个 todo 的异步操作，接受 `serialNum` 并返回 `TodoResponse`。
  ///
  /// Copied from [getTodo].
  const GetTodoFamily();

  /// 提供获取单个 todo 的异步操作，接受 `serialNum` 并返回 `TodoResponse`。
  ///
  /// Copied from [getTodo].
  GetTodoProvider call(
    String serialNum,
  ) {
    return GetTodoProvider(
      serialNum,
    );
  }

  @override
  GetTodoProvider getProviderOverride(
    covariant GetTodoProvider provider,
  ) {
    return call(
      provider.serialNum,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getTodoProvider';
}

/// 提供获取单个 todo 的异步操作，接受 `serialNum` 并返回 `TodoResponse`。
///
/// Copied from [getTodo].
class GetTodoProvider extends AutoDisposeFutureProvider<TodoResponse> {
  /// 提供获取单个 todo 的异步操作，接受 `serialNum` 并返回 `TodoResponse`。
  ///
  /// Copied from [getTodo].
  GetTodoProvider(
    String serialNum,
  ) : this._internal(
          (ref) => getTodo(
            ref as GetTodoRef,
            serialNum,
          ),
          from: getTodoProvider,
          name: r'getTodoProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$getTodoHash,
          dependencies: GetTodoFamily._dependencies,
          allTransitiveDependencies: GetTodoFamily._allTransitiveDependencies,
          serialNum: serialNum,
        );

  GetTodoProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.serialNum,
  }) : super.internal();

  final String serialNum;

  @override
  Override overrideWith(
    FutureOr<TodoResponse> Function(GetTodoRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetTodoProvider._internal(
        (ref) => create(ref as GetTodoRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        serialNum: serialNum,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<TodoResponse> createElement() {
    return _GetTodoProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetTodoProvider && other.serialNum == serialNum;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, serialNum.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin GetTodoRef on AutoDisposeFutureProviderRef<TodoResponse> {
  /// The parameter `serialNum` of this provider.
  String get serialNum;
}

class _GetTodoProviderElement
    extends AutoDisposeFutureProviderElement<TodoResponse> with GetTodoRef {
  _GetTodoProviderElement(super.provider);

  @override
  String get serialNum => (origin as GetTodoProvider).serialNum;
}

String _$todoListFetchHash() => r'0e5885614b0c9de3acc9a3795e4724684dce2f97';

/// 提供获取 todo 列表的异步操作，接受分页参数并返回 `List<TodoResponse>`。
///
/// Copied from [todoListFetch].
@ProviderFor(todoListFetch)
const todoListFetchProvider = TodoListFetchFamily();

/// 提供获取 todo 列表的异步操作，接受分页参数并返回 `List<TodoResponse>`。
///
/// Copied from [todoListFetch].
class TodoListFetchFamily extends Family<AsyncValue<List<TodoResponse>>> {
  /// 提供获取 todo 列表的异步操作，接受分页参数并返回 `List<TodoResponse>`。
  ///
  /// Copied from [todoListFetch].
  const TodoListFetchFamily();

  /// 提供获取 todo 列表的异步操作，接受分页参数并返回 `List<TodoResponse>`。
  ///
  /// Copied from [todoListFetch].
  TodoListFetchProvider call(
    PaginationParams params,
  ) {
    return TodoListFetchProvider(
      params,
    );
  }

  @override
  TodoListFetchProvider getProviderOverride(
    covariant TodoListFetchProvider provider,
  ) {
    return call(
      provider.params,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'todoListFetchProvider';
}

/// 提供获取 todo 列表的异步操作，接受分页参数并返回 `List<TodoResponse>`。
///
/// Copied from [todoListFetch].
class TodoListFetchProvider
    extends AutoDisposeFutureProvider<List<TodoResponse>> {
  /// 提供获取 todo 列表的异步操作，接受分页参数并返回 `List<TodoResponse>`。
  ///
  /// Copied from [todoListFetch].
  TodoListFetchProvider(
    PaginationParams params,
  ) : this._internal(
          (ref) => todoListFetch(
            ref as TodoListFetchRef,
            params,
          ),
          from: todoListFetchProvider,
          name: r'todoListFetchProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$todoListFetchHash,
          dependencies: TodoListFetchFamily._dependencies,
          allTransitiveDependencies:
              TodoListFetchFamily._allTransitiveDependencies,
          params: params,
        );

  TodoListFetchProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.params,
  }) : super.internal();

  final PaginationParams params;

  @override
  Override overrideWith(
    FutureOr<List<TodoResponse>> Function(TodoListFetchRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: TodoListFetchProvider._internal(
        (ref) => create(ref as TodoListFetchRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        params: params,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<TodoResponse>> createElement() {
    return _TodoListFetchProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TodoListFetchProvider && other.params == params;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, params.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TodoListFetchRef on AutoDisposeFutureProviderRef<List<TodoResponse>> {
  /// The parameter `params` of this provider.
  PaginationParams get params;
}

class _TodoListFetchProviderElement
    extends AutoDisposeFutureProviderElement<List<TodoResponse>>
    with TodoListFetchRef {
  _TodoListFetchProviderElement(super.provider);

  @override
  PaginationParams get params => (origin as TodoListFetchProvider).params;
}

String _$paginatedTodosHash() => r'8f45bdde0bf8c3d7f03c293854b7f080a895f167';

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
String _$totalTodoPagesHash() => r'd82412f32af359e7d7e4ab1af8415078d783631c';

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
String _$todoFilterNotifierHash() =>
    r'f41b026ac960a446cee13397b5dade29b96a44a5';

/// 提供过滤条件的 `StateNotifier`。
///
/// Copied from [TodoFilterNotifier].
@ProviderFor(TodoFilterNotifier)
final todoFilterNotifierProvider =
    AutoDisposeNotifierProvider<TodoFilterNotifier, TodoFilter>.internal(
  TodoFilterNotifier.new,
  name: r'todoFilterNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$todoFilterNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TodoFilterNotifier = AutoDisposeNotifier<TodoFilter>;
String _$todoPageNotifierHash() => r'32531a5eb019df0d470ff6abf88fbee3a742f517';

/// 提供分页状态的 `StateNotifier`。
///
/// Copied from [TodoPageNotifier].
@ProviderFor(TodoPageNotifier)
final todoPageNotifierProvider =
    AutoDisposeNotifierProvider<TodoPageNotifier, int>.internal(
  TodoPageNotifier.new,
  name: r'todoPageNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$todoPageNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TodoPageNotifier = AutoDisposeNotifier<int>;
String _$syncTriggerNotifierHash() =>
    r'120dd3a2534474abead42018144f377b296ca9b3';

/// 提供同步状态的 `StateNotifier`，用于触发同步。
///
/// Copied from [SyncTriggerNotifier].
@ProviderFor(SyncTriggerNotifier)
final syncTriggerNotifierProvider =
    AutoDisposeNotifierProvider<SyncTriggerNotifier, bool>.internal(
  SyncTriggerNotifier.new,
  name: r'syncTriggerNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncTriggerNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SyncTriggerNotifier = AutoDisposeNotifier<bool>;
String _$todoListHash() => r'4cb7fbcaab97f0f11769f7df3d3e0b79c8d5890b';

/// 管理本地待办事项列表，支持网络同步和本地操作。
///
/// Copied from [TodoList].
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
