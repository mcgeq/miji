import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

class HomeMonthBudgetCard extends StatelessWidget {
  const HomeMonthBudgetCard({
    super.key,
    required this.summary,
    required this.isLoading,
    required this.onCreateBudget,
  });

  final HomeMonthBudgetSummary? summary;
  final bool isLoading;
  final VoidCallback onCreateBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = summary;

    return AppContentPanel(
      title: '本月预算',
      subtitle: value?.budgetName,
      leadingWidget: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.flag_rounded,
          size: 16,
          color: theme.colorScheme.primary,
        ),
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 88,
              child: LinearProgressIndicator(minHeight: 3),
            )
          : null,
      child: value == null
          ? const SizedBox(height: 116)
          : value.hasBudget
          ? _BudgetState(summary: value)
          : _NoBudgetState(onCreateBudget: onCreateBudget),
    );
  }
}

class _NoBudgetState extends StatelessWidget {
  const _NoBudgetState({required this.onCreateBudget});

  final VoidCallback onCreateBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '未设置月度预算',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '设置后可查看本月还能花多少',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: onCreateBudget,
          icon: const Icon(Icons.add_rounded),
          label: const Text('去设置'),
        ),
      ],
    );
  }
}

class _BudgetState extends StatelessWidget {
  const _BudgetState({required this.summary});

  final HomeMonthBudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paceColor = _paceColor(theme);
    final progressLabelColor = _progressLabelColor(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProgressBar(
          progress: summary.progress,
          gradientColors: _barGradientColors(theme),
          labelColor: progressLabelColor,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PaceDot(color: paceColor, label: summary.paceLabel),
            const SizedBox(width: 16),
            _PaceDot(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              label: '周期 ${_percentText(summary.periodProgress)}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '还可花',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  MoneyAmountText(
                    amountMinor: summary.remainingMinor,
                    currencyCode: summary.currencyCode,
                    tone: summary.remainingMinor >= 0
                        ? MoneyAmountTone.income
                        : MoneyAmountTone.expense,
                    textStyle: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '日均可花',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                MoneyAmountText(
                  amountMinor: summary.dailyAllowanceMinor,
                  currencyCode: summary.currencyCode,
                  tone: MoneyAmountTone.neutral,
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '剩余 ${summary.remainingDays} 天',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '预算总额 ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                MoneyAmountText(
                  amountMinor: summary.totalMinor,
                  currencyCode: summary.currencyCode,
                  tone: MoneyAmountTone.neutral,
                  textStyle: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _percentText(double value) {
    return '${(value * 100).clamp(0, 999).toStringAsFixed(0)}%';
  }

  List<Color> _barGradientColors(ThemeData theme) {
    return [
      theme.moneyColors.success,
      theme.colorScheme.primary,
      theme.moneyColors.warning,
      theme.colorScheme.error,
    ];
  }

  Color _progressLabelColor(ThemeData theme) {
    final p = summary.progress;
    if (p >= 1) return theme.colorScheme.error;
    if (p >= 0.8) return theme.moneyColors.warning;
    if (p >= 0.5) return theme.colorScheme.primary;
    return theme.moneyColors.success;
  }

  Color _paceColor(ThemeData theme) {
    if (summary.progress >= 1) return theme.colorScheme.error;
    if (summary.paceLabel == '花费偏快') return theme.moneyColors.warning;
    return theme.moneyColors.success;
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.gradientColors,
    required this.labelColor,
  });

  final double progress;
  final List<Color> gradientColors;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const barHeight = 24.0;
    const borderRadius = 12.0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, child) {
        return SizedBox(
          height: barHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fillWidth = constraints.maxWidth * animatedProgress;
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: Container(
                      width: fillWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          stops: const [0.0, 0.35, 0.65, 1.0],
                        ),
                      ),
                    ),
                  ),
                  if (constraints.maxWidth > 200)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Text(
                          '${(animatedProgress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: animatedProgress > 0.5
                                ? Colors.white
                                : labelColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _PaceDot extends StatelessWidget {
  const _PaceDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
