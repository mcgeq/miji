import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/presentation/home_money_text.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 「今日行动」小卡：完成度 + 下一件待办。
class HomeTodayActionTile extends StatelessWidget {
  const HomeTodayActionTile({
    super.key,
    required this.view,
    required this.isLoading,
    required this.onTap,
  });

  final TodayActionView? view;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final view = this.view;
    final total = view?.totalCount ?? 0;
    final completed = view?.completedCount ?? 0;
    final progress = view?.completionRate ?? 0;

    return AppSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 15,
                color: colorScheme.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                '今日行动',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 28,
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else
                Text(
                  '$completed / $total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            total == 0 ? '暂无安排' : '$completed',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _nextLabel(view),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              color: colorScheme.secondary,
              backgroundColor: colorScheme.secondary.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }

  String _nextLabel(TodayActionView? view) {
    if (view == null) {
      return '正在读取…';
    }
    if (view.totalCount == 0) {
      return '今天没有待办';
    }
    for (final item in view.items) {
      if (!item.isCompleted) {
        return '下一件 · ${_titleOf(item)}';
      }
    }
    return '全部完成，收工 🎉';
  }

  String _titleOf(TodayActionItem item) {
    return switch (item) {
      TodayTodoActionItem(:final task) => task.title,
      TodayHabitActionItem(:final progress) => progress.plan.name,
    };
  }
}

/// 「净资产」小卡：资产 - 负债。
class HomeNetAssetTile extends StatelessWidget {
  const HomeNetAssetTile({
    super.key,
    required this.summary,
    required this.isLoading,
    required this.onTap,
  });

  final HomeNetAssetSummary? summary;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final value = summary ?? const HomeNetAssetSummary.empty();
    final income = theme.moneyColors.income;
    final ratio = value.assetMinor <= 0
        ? 0.0
        : (value.netAssetMinor / value.assetMinor).clamp(0.0, 1.0).toDouble();

    return AppSurface(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_rounded,
                size: 15,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '净资产',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 28,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (isLoading)
            SizedBox(height: theme.textTheme.headlineSmall?.fontSize)
          else
            HomeMoneyText(
              amountMinor: value.netAssetMinor,
              currencyCode: value.currencyCode,
              textStyle: theme.textTheme.headlineSmall,
            ),
          const SizedBox(height: 3),
          Text(
            '资产 / 负债拆分',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 7,
              color: income,
              backgroundColor: income.withValues(alpha: 0.14),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _Breakdown(
                  label: '资产',
                  amountMinor: value.assetMinor,
                  currencyCode: value.currencyCode,
                  color: income,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Breakdown(
                  label: '负债',
                  amountMinor: value.liabilityMinor,
                  currencyCode: value.currencyCode,
                  color: theme.moneyColors.expense,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.label,
    required this.amountMinor,
    required this.currencyCode,
    required this.color,
  });

  final String label;
  final int amountMinor;
  final String currencyCode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        HomeMoneyText(
          amountMinor: amountMinor,
          currencyCode: currencyCode,
          color: color,
          textStyle: theme.textTheme.labelLarge,
        ),
      ],
    );
  }
}
