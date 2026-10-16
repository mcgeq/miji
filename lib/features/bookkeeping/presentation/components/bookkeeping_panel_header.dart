import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 记账面板的统一页头。
///
/// 八个面板（流水 / 账户 / 预算 / 统计 / 分类 / 分期 / 自动记账 / 提醒）原来各写各的
/// 页头，同一件事在不同页的位置和样式都不一样：
///
/// - 搜索框：流水 / 预算 / 自动记账放在工具行**之上**，分类放在**之下**；
/// - 分段控件：流水拉满整行，分类 / 提醒居中；
/// - 新增按钮：账户 / 预算 / 分类 / 提醒和排序 / 筛选同排，分期 / 自动记账单独占一行。
///
/// 这里把顺序固定成三段，页面只往槽位里填：
///
///   1. [searchRow]   全宽搜索框（可带尾部控件），有列表搜索的页面才传；
///   2. [leading] + [actions]   工具行 —— 左边标题或分段控件，右边排序 / 筛选 / 新增；
///   3. [filtersRow]  筛选条 / 周期 chips。
///
/// [searchRow] 也接受 [BookkeepingPanelExpandableSearchRow]：那种页面把「搜索 +
/// 动作」合成一行（搜索默认折叠成图标、三枚按钮居中），此时不再传 [actions]，
/// 页头就只剩这一行。
///
/// 页面特有的区块（净资产 Hero、预算汇总条、冲突提示、提醒区）不属于页头，
/// 放在页头**之后**。搜索在最上、工具行其次，与最高频的流水页保持一致。
class BookkeepingPanelHeader extends StatelessWidget {
  const BookkeepingPanelHeader({
    super.key,
    this.searchRow,
    this.leading,
    this.actions = const <Widget>[],
    this.filtersRow,
  });

  /// 第一行：搜索框（可带尾部控件，如流水页的「筛选」开关）。没有搜索传 null。
  final Widget? searchRow;

  /// 第二行左侧：标题或分段控件。为空时动作按钮靠右。
  final Widget? leading;

  /// 第二行右侧的图标动作（排序 / 筛选 / 新增），按传入顺序排列。
  final List<Widget> actions;

  /// 第三行：筛选条 / 周期 chips。
  final Widget? filtersRow;

  @override
  Widget build(BuildContext context) {
    final hasToolbar = leading != null || actions.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (searchRow != null) ...[
          searchRow!,
          if (hasToolbar || filtersRow != null) const SizedBox(height: 10),
        ],
        if (hasToolbar)
          Row(
            children: [
              if (leading != null)
                Expanded(child: leading!)
              else
                const Spacer(),
              // leading 与第一个动作之间也要留间距，否则分段控件会贴着
              // 排序按钮（原来各页手动写的 `SizedBox(width: 8)`）。
              if (leading != null && actions.isNotEmpty)
                const SizedBox(width: 8),
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                actions[index],
              ],
            ],
          ),
        if (filtersRow != null) ...[const SizedBox(height: 10), filtersRow!],
      ],
    );
  }
}

/// 面板页头里的全宽搜索框。
///
/// 流水 / 预算 / 分类 / 自动记账四处原来是逐字复制的同一段 `AppTextField`
/// （控制器 + 放大镜前缀 + 有词时才出现的清除按钮）。抽出来只留调用方真正不同的
/// `hintText` 与 `onChanged`；清除按钮会清空控制器并以空串回调。
class BookkeepingPanelSearchField extends StatelessWidget {
  const BookkeepingPanelSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  /// 可选的焦点节点。[BookkeepingPanelExpandableSearchRow] 要靠它判断
  /// 「失焦且没填内容 → 收回图标态」。
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return AppTextField(
          controller: controller,
          focusNode: focusNode,
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded, size: 19),
          onChanged: onChanged,
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜索',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        );
      },
    );
  }
}

/// 面板页头的「可展开搜索行」。
///
/// - **折叠态**：搜索只占一枚图标按钮，与右侧动作按钮组成一组、**水平居中**；
/// - **点击图标**：搜索框在**这一行内**原地展开（300ms），动作按钮同时被推到最右；
/// - **失焦且没填内容**：自动收回图标态（有内容时不收——收起来就看不见搜索词了，
///   可筛选其实还在生效）。
///
/// 解决的是「搜索框独占一行、下面再排一行动作按钮」这类页头（预算）：默认白白
/// 花掉一行高度，只为放一个绝大多数时候空着的搜索框。折叠成图标后，搜索 / 筛选 /
/// 新增三枚按钮同排居中，真要搜索时再点开。
///
/// 折叠态刻意复用 [AppIconActionButton] 的 outlined 版（与同排的「筛选」同款），
/// 三枚按钮才读得出是一组，而不是「一个输入框 + 两个按钮」。
///
/// 判定「在哪里展开」不靠猜：动作组自身宽度实测一次（[GlobalKey]），展开态的
/// 搜索框宽度 = 行宽 − 动作组宽 − 间距；两侧留白按动画进度从「各占一半」（居中）
/// 收到「左侧归零」（按钮靠右）。
class BookkeepingPanelExpandableSearchRow extends StatefulWidget {
  const BookkeepingPanelExpandableSearchRow({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.actions,
    this.searchTooltip = '搜索',
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  /// 右侧动作按钮（筛选 / 新增…），按传入顺序排列，间隔 8。
  final List<Widget> actions;

  /// 折叠态那枚搜索图标按钮的 tooltip。
  final String searchTooltip;

  @override
  State<BookkeepingPanelExpandableSearchRow> createState() =>
      _BookkeepingPanelExpandableSearchRowState();
}

class _BookkeepingPanelExpandableSearchRowState
    extends State<BookkeepingPanelExpandableSearchRow>
    with SingleTickerProviderStateMixin {
  static const _gap = 8.0;
  static const _duration = Duration(milliseconds: 300);
  static const _curve = Curves.easeOutCubic;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _duration,
  );
  final FocusNode _focusNode = FocusNode();

  /// 用来实测动作组宽度——展开态的搜索框宽度要靠它算。
  final GlobalKey _actionsKey = GlobalKey();
  double? _actionsWidth;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _expand() {
    if (!_anim.isDismissed) {
      return;
    }
    _anim.forward();
    // 点这颗图标就是为了打字，展开后直接聚焦。延后一帧：输入框下一帧才插进树。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _collapse() {
    if (_anim.isDismissed) {
      return;
    }
    _anim.reverse();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && widget.controller.text.isEmpty) {
      _collapse();
    }
  }

  /// 首帧结束后量一次动作组宽度。
  ///
  /// 量到之前先按折叠态渲染（那时不需要知道宽度也能自然居中），所以不会闪。
  void _measureActionsWidth() {
    final box = _actionsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.width == _actionsWidth) {
      return;
    }
    setState(() => _actionsWidth = box.size.width);
  }

  @override
  Widget build(BuildContext context) {
    final controls = Theme.of(context).controlTokens;
    // 行高固定为输入框高度：折叠（40px 图标按钮）与展开（46px 输入框）两态同高，
    // 动画过程中整行不跳。
    return SizedBox(
      height: controls.fieldHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actionsWidth = _actionsWidth;
          if (actionsWidth == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _measureActionsWidth(),
            );
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSearchButton(),
                const SizedBox(width: _gap),
                _buildActions(),
              ],
            );
          }

          final collapsedWidth = controls.iconButtonSize;
          return AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final progress = _curve.transform(_anim.value);
              final clusterWidth = collapsedWidth + _gap + actionsWidth;
              final free = (constraints.maxWidth - clusterWidth).clamp(
                0.0,
                double.infinity,
              );
              return Row(
                children: [
                  // 折叠：左右各留一半 → 三枚按钮整体居中。
                  // 展开：左侧留白收到 0，余量全给搜索框 → 动作按钮被推到最右。
                  SizedBox(width: free * (1 - progress) / 2),
                  SizedBox(
                    width: collapsedWidth + free * progress,
                    child: _anim.isDismissed
                        ? _buildSearchButton()
                        : BookkeepingPanelSearchField(
                            controller: widget.controller,
                            hintText: widget.hintText,
                            onChanged: widget.onChanged,
                            focusNode: _focusNode,
                          ),
                  ),
                  const SizedBox(width: _gap),
                  _buildActions(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchButton() {
    return AppIconActionButton(
      tooltip: widget.searchTooltip,
      onPressed: _expand,
      icon: Icons.search_rounded,
      variant: AppIconActionVariant.outlined,
    );
  }

  Widget _buildActions() {
    return Row(
      key: _actionsKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < widget.actions.length; index++) ...[
          if (index > 0) const SizedBox(width: _gap),
          widget.actions[index],
        ],
      ],
    );
  }
}
