class HomeState {
  final bool isLoading;
  final List<String> todos;
  final String? error;
  final bool hasMore;
  final int currentPage;

  HomeState({
    this.isLoading = false,
    this.todos = const [],
    this.error,
    this.hasMore = true,
    this.currentPage = 1,
  });

  HomeState copyWith({
    bool? isLoading,
    List<String>? todos,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return HomeState(
      isLoading: isLoading ?? this.isLoading,
      todos: todos ?? this.todos,
      error: error ?? this.error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}