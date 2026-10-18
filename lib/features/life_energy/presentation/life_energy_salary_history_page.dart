import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/life_energy/application/life_energy_format.dart';
import 'package:miji/features/life_energy/domain/salary_history.dart';
import 'package:miji/features/life_energy/presentation/salary_segment_sheet.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';

/// 薪资历史：涨薪与跳槽。
///
/// 这一页只回答一件事：**我的时薪真的涨了吗**。税前涨 25% 是合同上的事，
/// 到手涨 23.8% 是税务口径的事，只有时薪同时算进了通勤和开销——而跳槽恰恰
/// 是那种「工资涨了、时薪没怎么涨」的常见情形。
class LifeEnergySalaryHistoryPage extends ConsumerWidget {
  const LifeEnergySalaryHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(salaryHistoryProvider);
    final theme = Theme.of(context);
    final spacing = theme.spacingTokens;
    final now = ref.watch(lifeEnergyClockProvider)();

    return Scaffold(
      appBar: AppBar(
        title: const Text('薪资历史'),
        actions: [
          IconButton(
            tooltip: '加一段',
            onPressed: () => showSalarySegmentSheet(context),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: history == null
          ? const AppSkeletonList(rows: 4)
          : history.segments.isEmpty
          ? AppEmptyState(
              title: '还没有记录',
              message: '涨薪或换工作时加上一段，之前的换算不会跟着变。',
              icon: Icons.timeline_rounded,
              action: FilledButton(
                onPressed: () => showSalarySegmentSheet(context),
                child: const Text('加一段'),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                spacing.pageCompact,
                8,
                spacing.pageCompact,
                32,
              ),
              children: [
                _IntroCard(currencyCode: history.profile.currencyCode),
                const SizedBox(height: 14),
                for (final view in history.views(now)) ...[
                  _SegmentCard(
                    view: view,
                    onTap: () =>
                        showSalarySegmentSheet(context, segment: view.segment),
                    onDelete: view.isCurrent
                        ? null
                        : () => _confirmDelete(context, ref, view),
                  ),
                  const SizedBox(height: 10),
                ],
                if (!history.hasHistory)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '只有一段时看不出「涨了多少」。下次涨薪或跳槽，再加一段。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SalarySegmentView view,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删掉这一段？',
      message:
          '删掉之后，${view.segment.effectiveYear} 年 '
          '${view.segment.effectiveMonth} 月起的这段时间会并回上一段。',
      confirmLabel: '删掉',
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    await ref.read(lifeEnergyActionsProvider).deleteSalarySegment(view.segment);
  }
}

/// 顶部那行小字：这一页最容易误解的地方是「为什么同一份工资在两个时点
/// 看出的天数不一样」，所以先写清楚「每一行用的是它自己那段的尺子」。
class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.currencyCode});

  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '每一行都用它自己那段的通勤和开销算。换过工作的话，'
              '旧行不会拿今天的路况去倒推。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentCard extends StatelessWidget {
  const _SegmentCard({required this.view, required this.onTap, this.onDelete});

  final SalarySegmentView view;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  /// 「个人 22.5% · 基数 ¥20,000」：核对工资条时用得上。
  ///
  /// 历史段用的是**当时冻下来的**那份参数（[SalarySegment.payroll]），
  /// 所以这一行读出来的就是当年算这笔钱的尺子，不是今天的比例。
  String _payrollLabel(SalarySegmentView view) {
    final config = view.profile.payroll;
    final base = config.baseFor(view.profile.grossMonthlyMinor);
    final rate = config.individualRateBp / 100;
    return '个人 ${rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 1)}%'
        ' · 基数 ${formatMoneyMinor(base, view.profile.currencyCode)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segment = view.segment;
    final currency = view.profile.currencyCode;
    final employer = view.employerLabel;
    final initial = employer.characters.first;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: view.isCurrent
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  initial,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: view.isCurrent
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            employer,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        if (view.isCurrent) ...[
                          const SizedBox(width: 6),
                          _Tag(
                            text: '当前',
                            color: theme.colorScheme.primary,
                            background: theme.colorScheme.primaryContainer,
                          ),
                        ] else if (view.isJobChange) ...[
                          const SizedBox(width: 6),
                          _Tag(
                            text: '跳槽',
                            color: theme.colorScheme.onSurfaceVariant,
                            background:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ] else if (view.isParameterAdjustment) ...[
                          const SizedBox(width: 6),
                          _Tag(
                            text: '参数调整',
                            color: theme.colorScheme.onSurfaceVariant,
                            background:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${segment.effectiveYear} 年 ${segment.effectiveMonth} 月起 · '
                      // 税前口径下两个都写：用户拿这一页跟工资条对的是税前，
                      // 而时薪是用到手算的 —— 只写一个他会对不上。
                      '${view.profile.isGrossMode ? '税前 ${formatMoneyMinor(view.profile.grossMonthlyMinor, currency)} · 到手 ' : ''}'
                      '${formatMoneyMinor(view.profile.payAmountMinor, currency)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                    if (view.profile.isGrossMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _payrollLabel(view),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    if (view.hourlyChangePercent != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _changeLabel(view.hourlyChangePercent!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: view.hourlyChangePercent! >= 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatLifeEnergyWage(
                      view.profile.hourlyWageMinor,
                      currency,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    '时薪',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              if (onDelete != null)
                PopupMenuButton<void>(
                  tooltip: '更多',
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem<void>(
                      onTap: onDelete,
                      child: const Text('删掉这一段'),
                    ),
                  ],
                )
              else
                const SizedBox(width: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _changeLabel(double percent) =>
      '${formatLifeEnergyDelta(percent)} 时薪 · 对比上一段';
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.color,
    required this.background,
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
