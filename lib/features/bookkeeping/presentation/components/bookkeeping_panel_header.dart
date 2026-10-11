import 'package:flutter/material.dart';

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
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return AppTextField(
          controller: controller,
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
