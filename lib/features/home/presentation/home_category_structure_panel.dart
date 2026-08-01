import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

// ============================================================================
// 主面板
// ============================================================================
class HomeCategoryStructurePanel extends StatefulWidget {
  const HomeCategoryStructurePanel({
    super.key,
    required this.items,
    required this.isLoading,
    required this.type,
    required this.onTypeChanged,
  });

  final List<HomeCategorySpendingItem> items;
  final bool isLoading;
  final HomeCategoryStructureType type;
  final ValueChanged<HomeCategoryStructureType> onTypeChanged;

  @override
  State<HomeCategoryStructurePanel> createState() =>
      _HomeCategoryStructurePanelState();
}

class _HomeCategoryStructurePanelState
    extends State<HomeCategoryStructurePanel> {
  String? _selectedSliceKey;

  @override
  void didUpdateWidget(covariant HomeCategoryStructurePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type != oldWidget.type || widget.items != oldWidget.items) {
      _selectedSliceKey = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleItems = widget.items.take(5).toList(growable: false);
    final slices = _prepareSliceData(widget.items, theme, widget.type);
    final selectedSlice = _selectedSlice(slices, _selectedSliceKey);
    final selectedCategoryId = selectedSlice?.categoryId;

    return AppContentPanel(
      title: '本月分类结构',
      leadingIcon: Icons.donut_large_rounded,
      keepTrailingInlineOnCompact: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSlidingSegmentedControl<HomeCategoryStructureType>(
            height: 30,
            minSegmentWidth: 48,
            value: widget.type,
            onChanged: widget.onTypeChanged,
            segments: [
              for (final value in HomeCategoryStructureType.values)
                AppSlidingSegment(value: value, label: value.label),
            ],
          ),
          if (widget.isLoading) ...[
            const SizedBox(width: 10),
            const SizedBox(
              width: 56,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ],
        ],
      ),
      child: widget.items.isEmpty
          ? _EmptyCategoryState(type: widget.type)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CategoryDonutChart(
                  slices: slices,
                  selectedSliceKey: selectedSlice?.key,
                  type: widget.type,
                  onSliceSelected: (key) {
                    setState(() => _selectedSliceKey = key);
                  },
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < visibleItems.length; index++) ...[
                  _CategoryRow(
                    item: visibleItems[index],
                    type: widget.type,
                    selected:
                        visibleItems[index].categoryId == selectedCategoryId,
                  ),
                  if (index != visibleItems.length - 1)
                    const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}

// ============================================================================
// 空状态（保持不变）
// ============================================================================
class _EmptyCategoryState extends StatelessWidget {
  const _EmptyCategoryState({required this.type});

  final HomeCategoryStructureType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 96,
      child: Center(
        child: Text(
          type.emptyText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 图表组件（重构核心）
// ============================================================================
class _CategoryDonutChart extends StatelessWidget {
  const _CategoryDonutChart({
    required this.slices,
    required this.selectedSliceKey,
    required this.type,
    required this.onSliceSelected,
  });

  final List<_CategoryChartSlice> slices;
  final String? selectedSliceKey;
  final HomeCategoryStructureType type;
  final ValueChanged<String> onSliceSelected;

  @override
  Widget build(BuildContext context) {
    final selectedSlice = _selectedSlice(slices, selectedSliceKey);

    return SizedBox(
      height: _ChartLayout.containerHeight,
      child: Row(
        children: [
          // 饼图主体
          SizedBox(
            width: _ChartLayout.chartSize,
            height: _ChartLayout.chartSize,
            child: PieChart(
              PieChartData(
                sectionsSpace: _ChartLayout.sectionsSpace,
                centerSpaceRadius: _ChartLayout.centerSpaceRadius,
                startDegreeOffset: _ChartLayout.startDegreeOffset,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    if (!event.isInterestedForInteractions) {
                      return;
                    }
                    final touchedIndex =
                        response?.touchedSection?.touchedSectionIndex ?? -1;
                    if (touchedIndex < 0 || touchedIndex >= slices.length) {
                      return;
                    }
                    onSliceSelected(slices[touchedIndex].key);
                  },
                ),
                sections: slices
                    .map(
                      (data) => PieChartSectionData(
                        value: data.value,
                        color: data.color,
                        radius: data.key == selectedSlice?.key
                            ? _ChartLayout.selectedSectionRadius
                            : _ChartLayout.sectionRadius,
                        showTitle: false,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          const SizedBox(width: 18),
          // 右侧摘要
          Expanded(
            child: selectedSlice != null
                ? _CenterSummary(slice: selectedSlice, type: type)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// 图表布局常量（消灭魔法数字）
// ----------------------------------------------------------------------------
class _ChartLayout {
  static const double containerHeight = 148.0;
  static const double chartSize = 136.0;
  static const double centerSpaceRadius = 32.0;
  static const double sectionRadius = 18.0;
  static const double selectedSectionRadius = 23.0;
  static const double sectionsSpace = 2.0;
  static const double startDegreeOffset = -90.0;
}

// ----------------------------------------------------------------------------
// 纯数据模型（UI 无关）
// ----------------------------------------------------------------------------
class _CategoryChartSlice {
  const _CategoryChartSlice({
    required this.key,
    required this.value,
    required this.color,
    required this.label,
    required this.amountMinor,
    required this.currencyCode,
    required this.ratio,
    this.categoryId,
  });

  final String key;
  final double value;
  final Color color;
  final String label;
  final int amountMinor;
  final String currencyCode;
  final double ratio;
  final String? categoryId;
}

// ----------------------------------------------------------------------------
// 数据转换 Mapper（纯函数，可单独单元测试）
// ----------------------------------------------------------------------------
List<_CategoryChartSlice> _prepareSliceData(
  List<HomeCategorySpendingItem> items,
  ThemeData theme,
  HomeCategoryStructureType type,
) {
  final colors = _chartColors(theme, type);
  final topItems = items.take(5).toList(growable: false);

  // 计算“其他”金额总和
  final otherAmount = items
      .skip(5)
      .fold<int>(0, (sum, e) => sum + e.amountMinor);

  final sections = <_CategoryChartSlice>[
    for (int i = 0; i < topItems.length; i++)
      _CategoryChartSlice(
        key: topItems[i].categoryId,
        value: topItems[i].amountMinor.toDouble(),
        color: colors[i % colors.length],
        label: topItems[i].categoryName,
        amountMinor: topItems[i].amountMinor,
        currencyCode: topItems[i].currencyCode,
        ratio: topItems[i].ratio,
        categoryId: topItems[i].categoryId,
      ),
  ];

  if (otherAmount > 0) {
    sections.add(
      _CategoryChartSlice(
        key: '__other__',
        value: otherAmount.toDouble(),
        color: theme.colorScheme.outlineVariant,
        label: '其他',
        amountMinor: otherAmount,
        currencyCode: items.first.currencyCode,
        ratio: _ratioFor(otherAmount, items),
      ),
    );
  }

  return sections;
}

_CategoryChartSlice? _selectedSlice(
  List<_CategoryChartSlice> slices,
  String? selectedKey,
) {
  if (slices.isEmpty) {
    return null;
  }
  for (final slice in slices) {
    if (slice.key == selectedKey) {
      return slice;
    }
  }
  return slices.first;
}

double _ratioFor(int amountMinor, List<HomeCategorySpendingItem> items) {
  final total = items.fold<int>(0, (sum, item) => sum + item.amountMinor);
  if (total <= 0) {
    return 0;
  }
  return amountMinor / total;
}

// ----------------------------------------------------------------------------
// 中心摘要信息（独立组件）
// ----------------------------------------------------------------------------
class _CenterSummary extends StatelessWidget {
  const _CenterSummary({required this.slice, required this.type});

  final _CategoryChartSlice slice;
  final HomeCategoryStructureType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(theme, type);
    final tone = _amountTone(type);

    return Column(
      key: const ValueKey('home-category-selected-summary'),
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当前分类',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          slice.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${(slice.ratio * 100).clamp(0, 100).toStringAsFixed(0)}%',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        MoneyAmountText(
          amountMinor: slice.amountMinor,
          currencyCode: slice.currencyCode,
          tone: tone,
          textStyle: theme.textTheme.labelLarge,
        ),
      ],
    );
  }
}

// ============================================================================
// 分类行（保持不变，依赖外部辅助函数）
// ============================================================================
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.type,
    required this.selected,
  });

  final HomeCategorySpendingItem item;
  final HomeCategoryStructureType type;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(theme, type);
    final percentage =
        '${(item.ratio * 100).clamp(0, 100).toStringAsFixed(0)}%';

    return AnimatedContainer(
      key: ValueKey('home-category-row-${item.categoryId}'),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? color.withValues(alpha: 0.34) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                percentage,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? color : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 10),
              MoneyAmountText(
                amountMinor: item.amountMinor,
                currencyCode: item.currencyCode,
                tone: _amountTone(type),
                textStyle: theme.textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: item.ratio.clamp(0, 1).toDouble(),
              minHeight: 7,
              color: color,
              backgroundColor: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 通用辅助函数
// ============================================================================
List<Color> _chartColors(ThemeData theme, HomeCategoryStructureType type) {
  final base = _typeColor(theme, type);
  final secondary = type == HomeCategoryStructureType.expense
      ? theme.moneyColors.warning
      : theme.colorScheme.primary;
  return [
    base,
    secondary,
    theme.moneyColors.transfer,
    theme.colorScheme.tertiary,
    base.withValues(alpha: 0.62),
  ];
}

Color _typeColor(ThemeData theme, HomeCategoryStructureType type) {
  return switch (type) {
    HomeCategoryStructureType.expense => theme.moneyColors.expense,
    HomeCategoryStructureType.income => theme.moneyColors.income,
  };
}

MoneyAmountTone _amountTone(HomeCategoryStructureType type) {
  return switch (type) {
    HomeCategoryStructureType.expense => MoneyAmountTone.expense,
    HomeCategoryStructureType.income => MoneyAmountTone.income,
  };
}
