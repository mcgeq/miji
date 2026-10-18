import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';

/// 横向分页里的一页：一个标签 + 若干纵向排列的区块。
class HomePagerPage {
  const HomePagerPage({required this.label, required this.children});

  final String label;
  final List<Widget> children;
}

/// 首页横向分页容器：概览 / 记账 / 健康 / 行动。
///
/// 滑到最后一页后继续滑会**绕回第一页**，反向同理。所以横向浏览是一个
/// 闭环，不会出现「到头了滑不动」的断点。
///
/// 实现方式是把 [PageView] 做成无限列表（`itemCount: null`），从
/// `页数 × _loopRounds` 页起步，再用取模把原始下标映射回真实页。
/// 不用「滑到边界后 jumpToPage」那种写法：那会先看到一次过冲回弹，
/// 再接一次瞬移，观感是「卡一下再跳」而不是连续滑动。
class HomePager extends StatefulWidget {
  const HomePager({super.key, required this.pages, required this.tabs});

  final List<HomePagerPage> pages;

  /// 顶部是否显示页签（默认关，靠滑动 + 底部圆点切换）。
  final bool tabs;

  @override
  State<HomePager> createState() => _HomePagerState();
}

class _HomePagerState extends State<HomePager> {
  /// 无限分页的起始圈数。
  ///
  /// 起始下标 = 页数 × 这个数，向左还有 1000 圈余量，正常使用永远滑不到头。
  static const _loopRounds = 1000;

  static const _animateDuration = Duration(milliseconds: 240);

  late final PageController _controller;

  /// 当前**真实**页下标（0 起），与 `_controller` 的原始下标不同：
  /// 后者是无限列表里的绝对位置。
  late int _index;

  int get _count => widget.pages.length;

  /// 页数 > 1 才值得循环；只有一页时没有「下一张」可言。
  bool get _loops => _count > 1;

  @override
  void initState() {
    super.initState();
    _index = 0;
    _controller = PageController(
      // 起点放在整圈上，保证 `rawPage % count == 0` 对应第一页。
      initialPage: _loops ? _count * _loopRounds : 0,
    );
  }

  @override
  void didUpdateWidget(covariant HomePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 页数变少时高亮下标可能越界（页签 / 圆点只会少亮一个，不会崩）。
    if (_index >= _count) {
      _index = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 把无限列表的原始下标折回真实页下标。
  int _normalize(int rawIndex) {
    if (_count == 0) {
      return 0;
    }
    return ((rawIndex % _count) + _count) % _count;
  }

  /// 当前滚动位置对应的原始下标（未取模）。
  int get _rawPage {
    if (!_controller.hasClients) {
      return _controller.initialPage;
    }
    return _controller.page?.round() ?? _controller.initialPage;
  }

  /// 循环翻页的最短步数，落在 `[-count/2, count/2]`。
  ///
  /// 从「概览」点「行动」时退一格左滑，而不是横穿三页，
  /// 否则点一下页签要滚过整屏内容，像卡住了一样。
  int _shortestDelta({required int from, required int to}) {
    final delta = (to - from) % _count;
    return delta > _count ~/ 2 ? delta - _count : delta;
  }

  void _goTo(int index) {
    if (index < 0 || index >= _count) {
      return;
    }
    if (!_loops) {
      _animateTo(index);
      return;
    }
    final current = _rawPage;
    final currentReal = _normalize(current);
    if (currentReal == index) {
      return;
    }
    _animateTo(current + _shortestDelta(from: currentReal, to: index));
  }

  void _animateTo(int rawPage) {
    if (!_controller.hasClients) {
      return;
    }
    _controller.animateToPage(
      rawPage,
      duration: _animateDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_count == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tabs)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var i = 0; i < _count; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      // 页签名可能与卡片里的模块名同名（如「记账」），
                      // 给一个稳定的 key，测试与无障碍都能精确命中页签。
                      key: ValueKey('home-pager-tab-${widget.pages[i].label}'),
                      onTap: () => _goTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? theme.colorScheme.surfaceContainerLow
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          widget.pages[i].label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: i == _index
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '‹ 左右滑动查看 '
              '${widget.pages.skip(1).map((p) => p.label).join(' · ')} ›',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            // null = 无限列表，左右都能一直滑下去（循环的关键）。
            itemCount: _loops ? null : _count,
            onPageChanged: (rawIndex) {
              final real = _normalize(rawIndex);
              if (real == _index) {
                return;
              }
              setState(() => _index = real);
            },
            itemBuilder: (context, rawIndex) {
              final page = widget.pages[_normalize(rawIndex)];
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (page.children.isEmpty)
                      _PagerEmpty(label: page.label)
                    else
                      for (var i = 0; i < page.children.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        page.children[i],
                      ],
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _count; i++)
              GestureDetector(
                onTap: () => _goTo(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PagerEmpty extends StatelessWidget {
  const _PagerEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      child: Column(
        children: [
          Text(
            '$label暂无显示内容',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '到设置里打开对应区块',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
