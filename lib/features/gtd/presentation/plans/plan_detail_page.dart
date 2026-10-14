import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:miji/core/notifications/notification_providers.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 计划详情页 — 历史记录 + 趋势曲线
class PlanDetailPage extends ConsumerWidget {
  const PlanDetailPage({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(activePlansProvider);
    final trendAsync = ref.watch(planTrendProvider(planId));
    final theme = Theme.of(context);
    // 右上角的删除按钮要在这里求值：AppBar 在 `plansAsync.when` 外面，
    // 拿不到里面的 `plan`。
    final plan = plansAsync.maybeWhen(
      data: (plans) => plans.where((p) => p.id == planId).firstOrNull,
      orElse: () => null,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划详情'),
        actions: [
          // 「任务详情」页一直有删除，计划这边却只有「计划管理」列表的溢出菜单能删。
          // 于是从「今日 / 习惯」列表点进来的习惯计划根本删不掉——用户看到的
          // 就是这个详情页，而它右上角是空的。
          if (plan != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '删除计划',
              onPressed: () => _confirmDelete(context, ref, plan),
            ),
        ],
      ),
      body: plansAsync.when(
        data: (plans) {
          final plan = plans.where((p) => p.id == planId).firstOrNull;
          if (plan == null) {
            return const Center(child: Text('计划不存在'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(plan.icon, style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${plan.category} · 目标: ${plan.targetUnit == '升' ? plan.targetValue.toStringAsFixed(1) : plan.targetValue.toInt()} ${plan.targetUnit}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '近 30 天趋势',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: trendAsync.when(
                  data: (trendData) {
                    if (trendData.isEmpty) {
                      return Center(
                        child: Text(
                          '暂无数据',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      );
                    }
                    return _TrendChart(data: trendData, theme: theme);
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('加载失败: $err')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
      ),
    );
  }

  /// 删除计划：与「任务详情」页同一套确认 + 反馈。
  ///
  /// 软删除（`isDeleted`），所以历史打卡记录仍在库里；只是这个计划不再出现在
  /// 「今日 / 习惯」列表里，也不会再触发提醒。
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CheckinPlan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除计划'),
        content: Text('「${plan.name}」会从今日与习惯列表里移除，历史打卡记录保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    await ref.read(checkinRepositoryProvider).deletePlan(plan.id);
    // 计划都没了，系统里排好的每日提醒也要撤掉，否则它还会按时弹出来。
    ref.read(appNotificationServiceProvider).cancelCheckinReminder(plan.id);
    // 用 Todo 那一侧的整套刷新：`invalidateCheckinData` 只管打卡自己的
    // provider，而「今日」tab 是 todo 与习惯混排的（`todayActionItemsProvider`），
    // 不刷它的话退回「今日」还会看到这条已经删掉的计划。
    invalidateTodayActionData(ref);

    if (!context.mounted) {
      return;
    }
    AppToast.success(FToast()..init(context), context, '计划已删除');
    Navigator.of(context).pop();
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data, required this.theme});

  final List<Map<String, dynamic>> data;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((entry) {
      final value = (entry.value['value'] as num?)?.toDouble() ?? 0;
      return FlSpot(entry.key.toDouble(), value);
    }).toList();

    if (spots.isEmpty) return const SizedBox.shrink();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.outline,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();
                final date = data[index]['date'] as DateTime;
                return Text(
                  '${date.month}/${date.day}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.outline,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, _, _) {
                return FlDotCirclePainter(
                  radius: 2.5,
                  color: theme.colorScheme.primary,
                  strokeWidth: 0,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
