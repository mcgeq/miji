import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

/// 首次使用引导：账户 / 预算 / 交易全为空时替代整个 dashboard。
///
/// 新用户面对一屏「0」很容易直接退出，这里给一条明确的下一步。
class HomeOnboardingView extends StatelessWidget {
  const HomeOnboardingView({
    super.key,
    required this.hasAccount,
    required this.hasBudget,
    required this.hasTransaction,
    required this.onCreateAccount,
    required this.onSetBudget,
    required this.onRecordTransaction,
  });

  final bool hasAccount;
  final bool hasBudget;
  final bool hasTransaction;
  final VoidCallback onCreateAccount;
  final VoidCallback onSetBudget;
  final VoidCallback onRecordTransaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final completed = [
      hasAccount,
      hasBudget,
      hasTransaction,
    ].where((value) => value).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
            gradient: theme.heroGradients.brand.linear,
            boxShadow: [
              BoxShadow(
                color: theme.heroGradients.brand.shadow.withValues(alpha: 0.3),
                blurRadius: 28,
                offset: const Offset(0, 14),
                spreadRadius: -16,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '欢迎使用米记 👋',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '三步开始你的记账：先建账户，再设预算，然后记下第一笔。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.6,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: completed / 3,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.24),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                '已完成 $completed / 3',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Step(
          index: 1,
          done: hasAccount,
          title: '创建第一个账户',
          subtitle: hasAccount ? '已创建' : '现金、银行卡、支付宝都可以',
          cta: hasAccount ? '已完成' : '去创建',
          onTap: hasAccount ? null : onCreateAccount,
        ),
        const SizedBox(height: 10),
        _Step(
          index: 2,
          done: hasBudget,
          title: '设置本月预算',
          subtitle: hasBudget ? '已设置' : '设置后首页会显示「还可花多少」',
          cta: hasBudget ? '已完成' : '去设置',
          onTap: hasBudget ? null : onSetBudget,
        ),
        const SizedBox(height: 10),
        _Step(
          index: 3,
          done: hasTransaction,
          title: '记下第一笔支出',
          subtitle: hasTransaction ? '已记录' : '支持支出 / 收入 / 转账',
          cta: hasTransaction ? '已完成' : '记一笔',
          onTap: hasTransaction ? null : onRecordTransaction,
        ),
        const SizedBox(height: 14),
        AppSurface(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '所有数据只存在你的设备上',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '支持 WebDAV 加密备份，随时可导出',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.done,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
  });

  final int index;
  final bool done;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = done ? theme.moneyColors.success : colorScheme.primary;

    return AppSurface(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? accent.withValues(alpha: 0.14)
                  : colorScheme.surfaceContainerHighest,
            ),
            child: done
                ? Icon(Icons.check_rounded, size: 15, color: accent)
                : Text(
                    '$index',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            cta,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
