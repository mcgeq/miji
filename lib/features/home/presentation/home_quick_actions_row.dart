import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/presentation/quick_actions/money_quick_action_launcher.dart';

/// 首页快捷记账入口。
///
/// 把悬浮按钮里的高频动作提到首屏，记一笔从「找到 FAB → 展开 → 选类型」
/// 变成一次点击。动作实现与 FAB 共用 [MoneyQuickActionLauncher]。
///
/// 只保留图标：标签文字会让这一行显得笨重，且四个动作在 FAB 面板与
/// Tooltip 里都有说明，图标本身也已足够表意。
class HomeQuickActionsRow extends StatelessWidget {
  const HomeQuickActionsRow({
    super.key,
    required this.actions,
    required this.onAction,
  });

  final List<MoneyQuickAction> actions;
  final ValueChanged<MoneyQuickAction> onAction;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          Expanded(
            child: _QuickActionButton(
              action: actions[index],
              onTap: () => onAction(actions[index]),
            ),
          ),
          if (index != actions.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action, required this.onTap});

  final MoneyQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(Theme.of(context), action);

    return Semantics(
      button: true,
      label: action.label,
      child: Tooltip(
        message: action.label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.13),
                  ),
                  child: Icon(action.icon, size: 21, color: color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFor(ThemeData theme, MoneyQuickAction action) {
    final moneyColors = theme.moneyColors;
    return switch (action) {
      MoneyQuickAction.expense => moneyColors.expense,
      MoneyQuickAction.income => moneyColors.income,
      MoneyQuickAction.transfer => moneyColors.transfer,
      MoneyQuickAction.budget => theme.colorScheme.primary,
      MoneyQuickAction.account => moneyColors.credit,
      MoneyQuickAction.task => theme.colorScheme.secondary,
      MoneyQuickAction.installment => moneyColors.warning,
      MoneyQuickAction.plan => theme.colorScheme.tertiary,
    };
  }
}
