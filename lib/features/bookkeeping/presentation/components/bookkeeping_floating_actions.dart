import 'package:flutter/material.dart';

import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';

/// 记账面板的**可拖动、默认靠边收起**的悬浮操作条。
///
/// 分期 / 自动记账这类面板原来在顶部放一整行「搜索 + 新增」：一行 62px 的空白带
/// 只挂两枚 40px 的按钮，居中悬在页面顶端，把列表又往下顶了一截。这两页的
/// 列表通常只有几条，那一行绝大多数时间是空的。
///
/// 现在顶部不再常驻任何东西，操作收进这枚悬浮条 ——
///
/// * **默认收起**：只剩一枚贴在屏幕边缘的手柄（22×40，不留缝），不挡内容；
///   点手柄整条从边缘拉出来；再点手柄推回去。箭头指向「点下去会往哪边走」；
/// * **拖动**：按住任意位置（含手柄）就能拖到屏幕上任意地方，松手后吸附到最近
///   的左右边缘（不吸附上下：纵向位置是用户自己挑的，别替他改）；
/// * **创建**：点「＋」直接打开创建界面，与原来顶栏那个按钮是同一个入口；
/// * **搜索**：点放大镜，搜索框在**页面顶部**出现（不再折叠进这一行）；
///   再点一次收起。搜索框收起即清空关键词 —— 输入框没了却还过滤着列表，
///   是「列表少了东西却找不到原因」里最难排查的一种。
///
/// 位置只记在内存里（面板活着就一直有效），不做持久化：这是「我现在顺手放哪」
/// 的临时偏好，写进设置反而会在换设备 / 换屏后指向一个不合理的位置。
///
/// 默认落点在右下角，但**避开全局的快速新增 FAB**：窄屏那个 FAB 是居中吸附的
/// （右下角空着），宽屏它在右下角（18 + 40），所以宽屏的落点再往上抬一截。
class BookkeepingFloatingActions extends StatefulWidget {
  /// 悬浮条本体。测试要按它量位置（按钮只是条里的一枚，量不到整条）。
  static const pillKey = ValueKey('bookkeeping-floating-actions');

  const BookkeepingFloatingActions({
    super.key,
    required this.child,
    required this.onCreate,
    required this.createTooltip,
    this.onSearch,
    this.searchTooltip = '搜索',
    this.searchExpanded = false,
  });

  /// 面板内容，撑满可用区域（内部用 `Positioned.fill` 给紧约束，
  /// 这样里面还能照常用 `Expanded`）。
  final Widget child;

  /// 打开创建界面。`null` 时按钮禁用（前置条件不满足，如没有信用账户）。
  final VoidCallback? onCreate;

  /// 创建按钮的说明；禁用时这里写「为什么不能用」。
  final String createTooltip;

  /// 展开 / 收起顶部搜索框。`null` 时不显示搜索入口（列表为空，搜无可搜）。
  ///
  /// 是**开关**而不是「只负责展开」：再点一次要能收回去，否则用户只能靠输入框
  /// 左端的放大镜关掉，而那枚放大镜在页面顶部、离刚点过的地方隔着整个列表。
  final VoidCallback? onSearch;

  final String searchTooltip;

  /// 顶部搜索框当前是否展开：展开时这枚图标的作用是「收起」，说明要跟着变。
  final bool searchExpanded;

  @override
  State<BookkeepingFloatingActions> createState() =>
      _BookkeepingFloatingActionsState();
}

class _BookkeepingFloatingActionsState
    extends State<BookkeepingFloatingActions> {
  static const double _margin = 12;
  static const double _buttonSize = 40;
  static const double _handleWidth = 22;
  static const double _pillHeight = 40;
  static const double _gap = 4;
  static const Duration _snapDuration = Duration(milliseconds: 180);

  /// 悬浮条左上角相对可用区域的偏移。`null` = 还没拖过，用默认落点。
  Offset? _offset;

  /// 拖动中：位置要跟手，不能带补间（否则会拖出一截延迟）。
  bool _dragging = false;

  /// 默认**收起**：这两页的列表通常只有几条，常驻一条 100 多 px 的操作条
  /// 挡住的是内容，不是空白。
  bool _collapsed = true;

  bool get _hasSearch => widget.onSearch != null;

  double get _expandedWidth =>
      _handleWidth + (_hasSearch ? _gap + _buttonSize : 0) + _gap + _buttonSize;

  double get _collapsedWidth => _handleWidth;

  double get _pillWidth => _collapsed ? _collapsedWidth : _expandedWidth;

  /// 收起时整条贴在屏幕边缘（不留缝，看起来就是「收进去了」），展开时退到边距。
  double get _edgeInset => _collapsed ? 0 : _margin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 被放进可滚动容器（约束无界）时没法定位，退化成只渲染内容：
        // 这些面板都是整屏的，正常不会走到这里，但不该因此崩掉。
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return widget.child;
        }
        final area = Size(constraints.maxWidth, constraints.maxHeight);
        final position = _clamp(_offset ?? _defaultOffset(context, area), area);
        // 手柄箭头的方向取决于整条当前贴在哪一侧。
        final toLeft = position.dx + _pillWidth / 2 < area.width / 2;

        return Stack(
          children: [
            Positioned.fill(child: widget.child),
            AnimatedPositioned(
              duration: _dragging ? Duration.zero : _snapDuration,
              curve: Curves.easeOutCubic,
              left: position.dx,
              top: position.dy,
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onPanStart: (_) => setState(() => _dragging = true),
                onPanUpdate: (details) {
                  final base = _offset ?? _defaultOffset(context, area);
                  setState(() => _offset = _clamp(base + details.delta, area));
                },
                onPanEnd: (_) => _snapToEdge(area),
                child: AnimatedContainer(
                  key: BookkeepingFloatingActions.pillKey,
                  duration: _dragging ? Duration.zero : _snapDuration,
                  curve: Curves.easeOutCubic,
                  width: _pillWidth,
                  height: _pillHeight,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: _borderRadius(toLeft),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.22),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  // 宽度是有补间的，内容不能跟着收缩：收起 → 展开的每一帧里，
                  // Row 会先按展开宽度排好、再被一个还只有手柄宽的盒子约束，
                  // 于是报 88px 溢出。这里让内容**恒定按展开宽度排版**，多出来的
                  // 部分交给外层的裁剪——看起来就是「按钮从边缘里被拉出来」。
                  child: OverflowBox(
                    alignment: AlignmentDirectional.centerStart,
                    minWidth: _expandedWidth,
                    maxWidth: _expandedWidth,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 手柄：既是拖把手，也是展开 / 收起的开关。
                        SizedBox(
                          width: _handleWidth,
                          height: _pillHeight,
                          child: AppIconActionButton(
                            tooltip: _collapsed ? '展开操作条' : '收起操作条',
                            onPressed: () => _toggleCollapsed(area),
                            icon: _handleIcon(toLeft),
                            iconSize: 18,
                            size: _handleWidth,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        if (!_collapsed) ...[
                          const SizedBox(width: _gap),
                          if (_hasSearch) ...[
                            AppIconActionButton(
                              // 展开状态下这枚图标的作用是收起，说明得跟着变。
                              // 与输入框左端那枚放大镜（tooltip 「收起搜索」）做的是
                              // 同一件事，文案刻意差一个字：两处同名的 tooltip 会让
                              // 「点哪枚都行」变成「谁也点不到」的歧义目标。
                              tooltip: widget.searchExpanded
                                  ? '收起搜索框'
                                  : widget.searchTooltip,
                              onPressed: widget.onSearch,
                              icon: Icons.search_rounded,
                            ),
                            const SizedBox(width: _gap),
                          ],
                          AppIconActionButton(
                            tooltip: widget.createTooltip,
                            onPressed: widget.onCreate,
                            icon: Icons.add_rounded,
                            variant: AppIconActionVariant.filled,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 箭头指向「点下去这条会往哪边走」：收起态往外（拉出来），展开态往边缘（推回去）。
  IconData _handleIcon(bool toLeft) => (_collapsed ? !toLeft : toLeft)
      ? Icons.chevron_left_rounded
      : Icons.chevron_right_rounded;

  /// 收起时贴边的那一侧是直的、另一侧是圆的，看起来才像「从边缘里拉出来的一半」。
  BorderRadius _borderRadius(bool toLeft) => _collapsed
      ? BorderRadius.horizontal(
          left: Radius.circular(toLeft ? 0 : _pillHeight / 2),
          right: Radius.circular(toLeft ? _pillHeight / 2 : 0),
        )
      : BorderRadius.circular(_pillHeight / 2);

  /// 默认落点：右下角，避开全局的快速新增 FAB。
  Offset _defaultOffset(BuildContext context, Size area) {
    final bottomInset = AppResponsive.of(context).isCompact ? 16.0 : 76.0;
    return Offset(
      area.width - _pillWidth - _edgeInset,
      area.height - _pillHeight - bottomInset,
    );
  }

  /// 松手后吸附到最近的左右边缘，纵向保持用户拖到的高度。
  void _snapToEdge(Size area) {
    final current = _clamp(_offset ?? _defaultOffset(context, area), area);
    final toLeft = current.dx + _pillWidth / 2 < area.width / 2;
    setState(() {
      _dragging = false;
      _offset = _clamp(_edgeOffset(area, toLeft, current.dy), area);
    });
  }

  /// 展开 / 收起：换边不换高度，横向贴回原来那一侧的边缘。
  void _toggleCollapsed(Size area) {
    final current = _clamp(_offset ?? _defaultOffset(context, area), area);
    final toLeft = current.dx + _pillWidth / 2 < area.width / 2;
    setState(() {
      _collapsed = !_collapsed;
      _offset = _clamp(_edgeOffset(area, toLeft, current.dy), area);
    });
  }

  Offset _edgeOffset(Size area, bool toLeft, double dy) =>
      Offset(toLeft ? _edgeInset : area.width - _pillWidth - _edgeInset, dy);

  Offset _clamp(Offset value, Size area) {
    final minX = _edgeInset;
    final maxX = area.width - _pillWidth - _edgeInset;
    final minY = _margin;
    final maxY = area.height - _pillHeight - _margin;
    return Offset(
      maxX <= minX ? minX : value.dx.clamp(minX, maxX),
      maxY <= minY ? minY : value.dy.clamp(minY, maxY),
    );
  }
}
