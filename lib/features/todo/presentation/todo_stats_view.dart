import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:miji/core/presentation/components/app_section_header.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';

// ---------------------------------------------------------------------------
// V1.2: 统计总页面 — 总览 / 任务 / 习惯
// ---------------------------------------------------------------------------

enum _StatsTab { overview, tasks, habits }

class V2StatisticsTab extends ConsumerStatefulWidget {
  const V2StatisticsTab({super.key});

  @override
  ConsumerState<V2StatisticsTab> createState() => _V2StatisticsTabState();
}

class _V2StatisticsTabState extends ConsumerState<V2StatisticsTab> {
  var _tab = _StatsTab.overview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TabChip(
                label: '总览',
                selected: _tab == _StatsTab.overview,
                onTap: () => setState(() => _tab = _StatsTab.overview),
              ),
              const SizedBox(width: 8),
              _TabChip(
                label: '任务',
                selected: _tab == _StatsTab.tasks,
                onTap: () => setState(() => _tab = _StatsTab.tasks),
              ),
              const SizedBox(width: 8),
              _TabChip(
                label: '习惯',
                selected: _tab == _StatsTab.habits,
                onTap: () => setState(() => _tab = _StatsTab.habits),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_tab) {
            _StatsTab.overview => const _OverviewStats(),
            _StatsTab.tasks => const _TodoStatsPanel(),
            _StatsTab.habits => const _HabitStatsPanel(),
          },
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurface,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primaryContainer,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}

// ---------------------------------------------------------------------------
// 总览
// ---------------------------------------------------------------------------

class _OverviewStats extends ConsumerWidget {
  const _OverviewStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoSummaryAsync = ref.watch(todoStatsSummaryProvider);
    final streakAsync = ref.watch(checkinStreakProvider);
    final progressAsync = ref.watch(todayProgressProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        AppSectionHeader(title: '任务'),
        const SizedBox(height: 8),
        todoSummaryAsync.when(
          data: (summary) => Row(
            children: [
              _MiniStatCard(
                label: '完成率',
                value: summary.completionRateText,
                icon: Icons.pie_chart_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              _MiniStatCard(
                label: '已完成',
                value: '${summary.totalCompleted}',
                icon: Icons.task_alt_rounded,
                color: Colors.green.shade400,
              ),
              const SizedBox(width: 10),
              _MiniStatCard(
                label: '逾期',
                value: '${summary.overdueCount}',
                icon: Icons.warning_rounded,
                color: summary.overdueCount > 0
                    ? colorScheme.error
                    : colorScheme.outline,
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        AppSectionHeader(title: '习惯'),
        const SizedBox(height: 8),
        Row(
          children: [
            streakAsync.when(
              data: (streak) => _MiniStatCard(
                label: '连续打卡',
                value: '${streak.currentStreak}天',
                icon: Icons.local_fire_department_rounded,
                color: Colors.orange,
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 10),
            progressAsync.when(
              data: (progressList) {
                final completed = progressList
                    .where((p) => p.completionRate >= 1.0)
                    .length;
                return _MiniStatCard(
                  label: '今日完成',
                  value: '$completed/${progressList.length}',
                  icon: Icons.today_rounded,
                  color: colorScheme.tertiary,
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Todo 任务统计面板
// ---------------------------------------------------------------------------

class _TodoStatsPanel extends ConsumerWidget {
  const _TodoStatsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(todoStatsRangeProvider);
    final summaryAsync = ref.watch(todoStatsSummaryProvider);
    final trendAsync = ref.watch(todoCompletionTrendProvider);
    final catDistAsync = ref.watch(todoCategoryDistributionProvider);
    final tagDistAsync = ref.watch(todoTagDistributionProvider);
    final priDistAsync = ref.watch(todoPriorityDistributionProvider);
    final tipsAsync = ref.watch(todoReviewTipsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // 范围选择
        Row(
          children: [
            for (final r in TodoStatsRange.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    TodoStatsRangeInfo.forRange(r).label,
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: range == r,
                  onSelected: (_) =>
                      ref.read(todoStatsRangeProvider.notifier).set(r),
                  selectedColor: colorScheme.primaryContainer,
                ),
              ),
            const Spacer(),
            // CSV 导出
            IconButton(
              icon: Icon(
                Icons.file_download_outlined,
                size: 20,
                color: colorScheme.outline,
              ),
              tooltip: '导出 CSV',
              onPressed: () => _exportCsv(context, ref, range),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 执行摘要
        summaryAsync.when(
          data: (s) => _buildSummary(context, s),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('加载失败: $e'),
        ),
        const SizedBox(height: 16),
        // 完成趋势
        AppSectionHeader(title: '完成趋势'),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: trendAsync.when(
            data: (trend) => _buildTrendChart(context, trend, colorScheme),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 16),
        // 分类分布
        catDistAsync.when(
          data: (d) => _buildDistribution(context, '分类分布', d, colorScheme),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        // 标签分布
        tagDistAsync.when(
          data: (d) => _buildDistribution(context, '标签分布', d, colorScheme),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        // 优先级分布
        priDistAsync.when(
          data: (d) => _buildDistribution(context, '优先级分布', d, colorScheme),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        // 复盘提示
        tipsAsync.when(
          data: (tips) {
            if (tips.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                AppSectionHeader(title: '复盘提示'),
                const SizedBox(height: 8),
                ...tips.map(
                  (tip) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(tip.colorValue).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Color(tip.colorValue).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          switch (tip.type) {
                            TodoReviewTipType.danger =>
                              Icons.error_outline_rounded,
                            TodoReviewTipType.warning =>
                              Icons.warning_amber_rounded,
                            TodoReviewTipType.success =>
                              Icons.check_circle_outline_rounded,
                          },
                          color: Color(tip.colorValue),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip.message,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, TodoStatsSummary s) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _StatTile(
          icon: Icons.assignment_rounded,
          label: '计划任务',
          value: '${s.plannedCount}',
          color: theme.colorScheme.primary,
        ),
        _StatTile(
          icon: Icons.task_alt_rounded,
          label: '完成率',
          value: s.completionRateText,
          color: Colors.green.shade400,
        ),
        _StatTile(
          icon: Icons.warning_rounded,
          label: '逾期',
          value: '${s.overdueCount}',
          color: s.overdueCount > 0
              ? theme.colorScheme.error
              : theme.colorScheme.outline,
        ),
        _StatTile(
          icon: Icons.cancel_rounded,
          label: '已取消',
          value: '${s.cancelledCount}',
          color: theme.colorScheme.outline,
        ),
      ],
    );
  }

  Widget _buildTrendChart(
    BuildContext context,
    List<TodoDailyTrend> trend,
    ColorScheme colorScheme,
  ) {
    if (trend.isEmpty) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              trend.length,
              (i) => FlSpot(i.toDouble(), trend[i].count.toDouble()),
            ),
            isCurved: true,
            color: colorScheme.primary,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, _, _, _) =>
                  FlDotCirclePainter(radius: 3, color: colorScheme.primary),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistribution(
    BuildContext context,
    String title,
    List<TodoDistribution> items,
    ColorScheme colorScheme,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final displayed = items.length > 5 ? items.take(4).toList() : items;
    final otherCount = items.length > 5
        ? items.skip(4).fold<int>(0, (s, i) => s + i.count)
        : 0;
    final total = items.fold<int>(0, (s, i) => s + i.count);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        AppSectionHeader(title: title),
        const SizedBox(height: 6),
        ...displayed.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Row(
                    children: [
                      if (d.color != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(d.color!.replaceFirst('#', '0xff')),
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          d.label ?? d.key,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: total > 0 ? d.count / total : 0,
                      minHeight: 6,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        d.color != null
                            ? Color(
                                int.parse(d.color!.replaceFirst('#', '0xff')),
                              )
                            : colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${d.count}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (otherCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '其他 $otherCount 项',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref,
    TodoStatsRange range,
  ) async {
    try {
      final repo = ref.read(todoRepositoryProvider);
      final session = ref.read(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return;

      final rangeInfo = TodoStatsRangeInfo.forRange(range);
      final csv = await repo.exportTasksCsv(userId, rangeInfo);
      if (csv.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('当前范围没有可导出的任务')));
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/miji_tasks_${rangeInfo.label}.csv');
      await file.writeAsString(csv);

      if (context.mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            subject: 'Miji Todo 导出 - ${rangeInfo.label}',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 习惯统计面板（保留原有内容）
// ---------------------------------------------------------------------------

class _HabitStatsPanel extends ConsumerWidget {
  const _HabitStatsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(checkinStreakProvider);
    final categoryStatsAsync = ref.watch(categoryStatsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        streakAsync.when(
          data: (streak) => Row(
            children: [
              _StatCard(
                label: '当前连续',
                value: '${streak.currentStreak}',
                unit: '天',
                icon: Icons.local_fire_department_rounded,
                color: streak.currentStreak > 0
                    ? Colors.orange
                    : colorScheme.outline,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: '最长连续',
                value: '${streak.longestStreak}',
                unit: '天',
                icon: Icons.emoji_events_rounded,
                color: streak.longestStreak > 0
                    ? Colors.amber.shade700
                    : colorScheme.outline,
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        AppSectionHeader(title: '本月分类统计'),
        const SizedBox(height: 10),
        categoryStatsAsync.when(
          data: (stats) {
            if (stats.isEmpty) {
              return Text(
                '暂无数据',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.outline,
                ),
              );
            }
            final total = stats.values.fold<int>(0, (a, b) => a + b);
            return Column(
              children: stats.entries.map((entry) {
                final rate = total > 0 ? entry.value / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: rate,
                            minHeight: 8,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${entry.value}',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('加载失败: $err'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });
  final String label, value, unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Expanded(
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      text: value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: ' $unit',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
