import 'package:flutter/material.dart';

class PagedLoadMoreList<T> extends StatefulWidget {
  const PagedLoadMoreList({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.hasMore,
    required this.onLoadMore,
    this.onRefresh,
    this.separatorBuilder,
    this.emptyBuilder,
    this.padding,
    this.loadMoreThreshold = 240,
    this.physics,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final bool hasMore;
  final Future<void> Function() onLoadMore;
  final Future<void> Function()? onRefresh;
  final WidgetBuilder? emptyBuilder;
  final EdgeInsetsGeometry? padding;
  final double loadMoreThreshold;
  final ScrollPhysics? physics;

  @override
  State<PagedLoadMoreList<T>> createState() => _PagedLoadMoreListState<T>();
}

class _PagedLoadMoreListState<T> extends State<PagedLoadMoreList<T>> {
  bool _isLoadingMore = false;

  @override
  Widget build(BuildContext context) {
    final list = widget.items.isEmpty ? _buildEmpty(context) : _buildList();
    if (widget.onRefresh == null) {
      return list;
    }

    return RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
  }

  Widget _buildEmpty(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: widget.padding ?? EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 240),
          child: Center(child: widget.emptyBuilder?.call(context)),
        ),
      ),
    );
  }

  Widget _buildList() {
    final itemCount = widget.items.length + 1;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter <= widget.loadMoreThreshold) {
          _loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: widget.padding,
        physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == widget.items.length) {
            return _PagedLoadMoreFooter(
              hasMore: widget.hasMore,
              isLoading: _isLoadingMore,
              onLoadMore: _loadMore,
            );
          }
          return widget.itemBuilder(context, widget.items[index], index);
        },
        separatorBuilder: (context, index) {
          if (index >= widget.items.length - 1) {
            return const SizedBox.shrink();
          }
          return widget.separatorBuilder?.call(context, index) ??
              const SizedBox(height: 10);
        },
      ),
    );
  }

  Future<void> _loadMore() async {
    if (!widget.hasMore || _isLoadingMore) {
      return;
    }

    setState(() => _isLoadingMore = true);
    try {
      await widget.onLoadMore();
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }
}

class _PagedLoadMoreFooter extends StatelessWidget {
  const _PagedLoadMoreFooter({
    required this.hasMore,
    required this.isLoading,
    required this.onLoadMore,
  });

  final bool hasMore;
  final bool isLoading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            '没有更多了',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: TextButton.icon(
          onPressed: onLoadMore,
          icon: const Icon(Icons.expand_more_rounded),
          label: const Text('加载更多'),
        ),
      ),
    );
  }
}
