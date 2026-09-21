import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

/// 环形图与图例并排所需的最小宽度。低于这个值就上下排，
/// 否则图例列会被压到放不下分类名。
const _sideBySideMinWidth = 400.0;

/// 本月分类结构：环形图 + 图例列表。
///
/// 环形图中心显示当前选中分类，右侧图例直接给出占比条；点击扇区或图例
/// 都会同步高亮，避免「必须点中扇区才能看到明细」。
class HomeCategoryStructurePanel extends StatefulWidget {
  const HomeCategoryStructurePanel({
    super.key,
    required this.items,
    required this.isLoading,
    required this.type,
    required this.onTypeChanged,
    this.maxRows = 4,
  });

  final List<HomeCategorySpendingItem> items;
  final bool isLoading;
  final HomeCategoryStructureType type;
  final ValueChanged<HomeCategoryStructureType> onTypeChanged;
  final int maxRows;

  @override
  State<HomeCategoryStructurePanel> createState() =>
      _HomeCategoryStructurePanelState();
}

class _HomeCategoryStructurePanelState
    extends State<HomeCategoryStructurePanel> {
  String? _selectedCategoryId;

  @override
  void didUpdateWidget(covariant HomeCategoryStructurePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.type != oldWidget.type || widget.items != oldWidget.items) {
      _selectedCategoryId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slices = _buildSlices(widget.items, theme, widget.type);
    final selected = _selectedSlice(slices, _selectedCategoryId);
    final rows = widget.items.take(widget.maxRows).toList(growable: false);

    return AppContentPanel(
      title: '本月分类',
      subtitle: widget.items.isEmpty ? null : '共 ${widget.items.length} 个分类',
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
              width: 48,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ],
        ],
      ),
      child: widget.items.isEmpty
          ? _EmptyState(type: widget.type)
          : LayoutBuilder(
              builder: (context, constraints) {
                // 环形图与图例并排时，图例列只剩不到 200px，分类名会被截断
                // （「人情往来」这类 4 字名都放不下）。宽度不够就改成上下排，
                // 让图例拿到整行宽度。
                final sideBySide = constraints.maxWidth >= _sideBySideMinWidth;
                final donut = _Donut(
                  slices: slices,
                  selected: selected,
                  type: widget.type,
                  onSelect: (key) {
                    setState(() => _selectedCategoryId = key);
                  },
                );
                final legend = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < rows.length; index++) ...[
                      _CategoryRow(
                        item: rows[index],
                        type: widget.type,
                        color: _colorFor(slices, rows[index].categoryId),
                        selected:
                            rows[index].categoryId == selected?.categoryId,
                        onTap: () {
                          setState(
                            () => _selectedCategoryId = rows[index].categoryId,
                          );
                        },
                      ),
                      if (index != rows.length - 1) const SizedBox(height: 9),
                    ],
                  ],
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sideBySide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          donut,
                          const SizedBox(width: 16),
                          Expanded(child: legend),
                        ],
                      )
                    else ...[
                      Center(child: donut),
                      const SizedBox(height: 16),
                      legend,
                    ],
                    if (widget.items.length > rows.length) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '另有 ${widget.items.length - rows.length} 个分类未展示',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.type});

  final HomeCategoryStructureType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 120,
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

/// 环形图 + 中心摘要。
class _Donut extends StatelessWidget {
  const _Donut({
    required this.slices,
    required this.selected,
    required this.type,
    required this.onSelect,
  });

  final List<_CategorySlice> slices;
  final _CategorySlice? selected;
  final HomeCategoryStructureType type;
  final ValueChanged<String> onSelect;

  static const _size = 128.0;
  static const _centerRadius = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _typeColor(theme, type);
    final selected = this.selected;

    return SizedBox.square(
      dimension: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: _centerRadius,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions) {
                    return;
                  }
                  final index =
                      response?.touchedSection?.touchedSectionIndex ?? -1;
                  if (index < 0 || index >= slices.length) {
                    return;
                  }
                  onSelect(slices[index].key);
                },
              ),
              sections: [
                for (final slice in slices)
                  PieChartSectionData(
                    value: slice.value,
                    color: slice.color,
                    radius: slice.key == selected?.key ? 19 : 15,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: _size - _centerRadius * 2,
            child: selected == null
                ? const SizedBox.shrink()
                : Column(
                    key: const ValueKey('home-category-selected-summary'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(selected.ratio * 100).clamp(0, 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 1),
                      MoneyAmountText(
                        amountMinor: selected.amountMinor,
                        currencyCode: selected.currencyCode,
                        tone: _amountTone(type),
                        textStyle: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.type,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final HomeCategorySpendingItem item;
  final HomeCategoryStructureType type;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _typeColor(theme, type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          key: ValueKey('home-category-row-${item.categoryId}'),
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.34)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 名字单独占一行、只有它是弹性的：金额与百分比都是非弹性子项，
              // 一旦它们的固有宽度超过行宽，Row 会溢出并把名字挤成 0 宽
              // （旧实现就是这样，看起来像「分类名显示不全」）。
              LayoutBuilder(
                builder: (context, constraints) {
                  // 金额最多占行宽的 55%：既保证正常金额完整显示，
                  // 又从构造上排除「非弹性子项撑破整行」的可能。
                  final amountMaxWidth = constraints.maxWidth * 0.55;
                  return Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          item.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w900
                                : FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: amountMaxWidth),
                        child: MoneyAmountText(
                          amountMinor: item.amountMinor,
                          currencyCode: item.currencyCode,
                          tone: _amountTone(type),
                          textStyle: theme.textTheme.labelMedium,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: item.ratio.clamp(0, 1).toDouble(),
                        minHeight: 5,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(item.ratio * 100).clamp(0, 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
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

// ============================================================================
// 数据换算
// ============================================================================

class _CategorySlice {
  const _CategorySlice({
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

const _otherKey = '__other__';

List<_CategorySlice> _buildSlices(
  List<HomeCategorySpendingItem> items,
  ThemeData theme,
  HomeCategoryStructureType type,
) {
  if (items.isEmpty) {
    return const [];
  }

  final palette = _slicePalette(theme, type);
  final top = items.take(5).toList(growable: false);
  final otherAmount = items
      .skip(5)
      .fold<int>(0, (sum, e) => sum + e.amountMinor);
  final total = items.fold<int>(0, (sum, item) => sum + item.amountMinor);

  return [
    for (var index = 0; index < top.length; index++)
      _CategorySlice(
        key: top[index].categoryId,
        value: top[index].amountMinor.toDouble(),
        color: palette[index % palette.length],
        label: top[index].categoryName,
        amountMinor: top[index].amountMinor,
        currencyCode: top[index].currencyCode,
        ratio: top[index].ratio,
        categoryId: top[index].categoryId,
      ),
    if (otherAmount > 0)
      _CategorySlice(
        key: _otherKey,
        value: otherAmount.toDouble(),
        color: theme.colorScheme.outlineVariant,
        label: '其他',
        amountMinor: otherAmount,
        currencyCode: items.first.currencyCode,
        ratio: total == 0 ? 0 : otherAmount / total,
      ),
  ];
}

_CategorySlice? _selectedSlice(
  List<_CategorySlice> slices,
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

Color _colorFor(List<_CategorySlice> slices, String categoryId) {
  for (final slice in slices) {
    if (slice.key == categoryId) {
      return slice.color;
    }
  }
  return slices.isEmpty ? Colors.grey : slices.last.color;
}

List<Color> _slicePalette(ThemeData theme, HomeCategoryStructureType type) {
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
