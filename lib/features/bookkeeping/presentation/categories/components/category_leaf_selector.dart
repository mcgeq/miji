import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/presentation/categories/category_icon.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 可选中的一个「叶子」：子分类，或没有子分类的父分类本身。
///
/// 记账时用户想的是「午餐」而不是「餐饮 → 午餐」，所以表单直接摊平到叶子，
/// 父分类由叶子反推（写回 `categoryId`）。筛选器 / 预算的作用域选择器仍然
/// 保留两级——「整个餐饮」在那里是有意义的目标。
@immutable
class CategoryLeaf {
  const CategoryLeaf({required this.category, this.subCategory});

  final MoneyCategoryEntity category;
  final MoneySubCategoryEntity? subCategory;

  /// 写回流水的分类 id。
  String get categoryId => category.id;

  /// 写回流水的子分类 id（父分类作叶子时为 null）。
  String? get subCategoryId => subCategory?.id;

  String get name => subCategory?.name ?? category.name;

  String? get colorHex => subCategory?.color ?? category.color;

  String? get iconName => subCategory?.icon ?? category.icon;

  /// 叶子是子分类（而非父分类本身）。
  bool get isChild => subCategory != null;

  /// 同一父分类下的叶子共用一个 key（用于选中判断）。
  String get key => '${category.id}::${subCategory?.id ?? ''}';

  static String keyOf(String? categoryId, String? subCategoryId) =>
      '${categoryId ?? ''}::${subCategoryId ?? ''}';
}

/// 把目录摊平成叶子列表。
///
/// * [fixedCategoryId] 指定时只返回该分类下的叶子（转账表单用：父分类固定）；
/// * 没有（未停用）子分类的父分类本身作为一个叶子，否则它永远选不到。
List<CategoryLeaf> buildCategoryLeaves(
  MoneyCategoryCatalog catalog, {
  String? fixedCategoryId,
}) {
  final leaves = <CategoryLeaf>[];
  for (final category in catalog.categories) {
    if (category.isDeleted) {
      continue;
    }
    if (fixedCategoryId != null && category.id != fixedCategoryId) {
      continue;
    }
    final subCategories = catalog
        .subCategoriesFor(category.id)
        .where((item) => !item.isDeleted)
        .toList();
    if (subCategories.isEmpty) {
      leaves.add(CategoryLeaf(category: category));
      continue;
    }
    for (final subCategory in subCategories) {
      leaves.add(CategoryLeaf(category: category, subCategory: subCategory));
    }
  }
  return leaves;
}

/// 「常用」比较器：最近使用 → 使用次数 → 累计金额 → 目录顺序。
///
/// 网格（扁平取前 N）和「全部分类」面板（按父分类分组后组内排序）**共用这一个**，
/// 避免出现「格子里排第一、面板里却翻很久才找到」的两套口径。
int compareLeavesByUsage(
  CategoryLeaf left,
  CategoryLeaf right,
  MoneyCategoryUsage? usage,
  Map<String, int> catalogIndex,
) {
  if (usage != null && !usage.isEmpty) {
    final compare = MoneyCategoryUsage.compareUsageStats(
      usage.statForLeaf(left.categoryId, left.subCategoryId),
      usage.statForLeaf(right.categoryId, right.subCategoryId),
    );
    if (compare != 0) {
      return compare;
    }
  }
  return (catalogIndex[left.key] ?? 0).compareTo(catalogIndex[right.key] ?? 0);
}

/// 按「常用」排序的叶子列表（不截断）。
List<CategoryLeaf> sortLeavesByUsage(
  List<CategoryLeaf> leaves,
  MoneyCategoryUsage? usage,
) {
  final catalogIndex = <String, int>{
    for (var i = 0; i < leaves.length; i++) leaves[i].key: i,
  };
  final ranked = List<CategoryLeaf>.of(leaves);
  ranked.sort((a, b) => compareLeavesByUsage(a, b, usage, catalogIndex));
  return ranked;
}

/// 按「常用」排序后的前 [count] 个叶子。
List<CategoryLeaf> pickFrequentLeaves(
  List<CategoryLeaf> leaves,
  MoneyCategoryUsage? usage, {
  int count = 9,
}) {
  if (leaves.isEmpty) {
    return const <CategoryLeaf>[];
  }
  if (usage == null || usage.isEmpty) {
    return leaves.take(count).toList();
  }
  return sortLeavesByUsage(leaves, usage).take(count).toList();
}

/// 叶子分类选择器。
///
/// 常用叶子做成网格直接点（一次点击完成），「全部分类」打开带搜索的分组列表，
/// 分组标题本身可点 = 只记到父分类（保留原有的「不选子分类」能力）。
class CategoryLeafSelector extends StatelessWidget {
  const CategoryLeafSelector({
    super.key,
    required this.catalog,
    required this.selectedCategoryId,
    required this.selectedSubCategoryId,
    required this.onChanged,
    this.usage,
    this.fixedCategoryId,
    this.frequentCount = 9,
    this.enabled = true,
  });

  final MoneyCategoryCatalog catalog;
  final String? selectedCategoryId;
  final String? selectedSubCategoryId;
  final void Function(String categoryId, String? subCategoryId) onChanged;
  final MoneyCategoryUsage? usage;

  /// 父分类固定时（转账），只展示它的叶子，并且不再强调归属。
  final String? fixedCategoryId;
  final int frequentCount;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leaves = buildCategoryLeaves(
      catalog,
      fixedCategoryId: fixedCategoryId,
    );
    if (leaves.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.4,
          ),
        ),
        child: Text(
          '暂无可选分类',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      );
    }

    final frequent = pickFrequentLeaves(leaves, usage, count: frequentCount);
    final selectedKey = CategoryLeaf.keyOf(
      selectedCategoryId,
      selectedSubCategoryId,
    );
    final selectedLeaf = leaves
        .where((leaf) => leaf.key == selectedKey)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selectedLeaf != null) ...[
          _SelectedLeafBanner(
            leaf: selectedLeaf,
            showParent: fixedCategoryId == null && selectedLeaf.isChild,
          ),
          const SizedBox(height: 8),
        ],
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.45,
          children: [
            for (final leaf in frequent)
              _LeafTile(
                leaf: leaf,
                selected: leaf.key == selectedKey,
                showParent: fixedCategoryId == null && leaf.isChild,
                enabled: enabled,
                onTap: () => onChanged(leaf.categoryId, leaf.subCategoryId),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: enabled
                    ? () => _openAllLeaves(context, leaves)
                    : null,
                icon: const Icon(Icons.grid_view_rounded, size: 17),
                label: Text('全部分类（${leaves.length}）'),
              ),
            ),
            if (fixedCategoryId != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: enabled
                    ? () => onChanged(fixedCategoryId!, null)
                    : null,
                child: const Text('不选子分类'),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _openAllLeaves(
    BuildContext context,
    List<CategoryLeaf> leaves,
  ) async {
    final picked = await showCategoryLeafSheet(
      context: context,
      leaves: leaves,
      usage: usage,
      selectedKey: CategoryLeaf.keyOf(
        selectedCategoryId,
        selectedSubCategoryId,
      ),
      showParent: fixedCategoryId == null,
    );
    if (picked != null) {
      onChanged(picked.categoryId, picked.subCategoryId);
    }
  }
}

class _SelectedLeafBanner extends StatelessWidget {
  const _SelectedLeafBanner({required this.leaf, required this.showParent});

  final CategoryLeaf leaf;
  final bool showParent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = appColorFromHex(leaf.colorHex);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          CategoryIconWidget(leaf.iconName, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              showParent ? '${leaf.category.name} · ${leaf.name}' : leaf.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          Text(
            '已选',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeafTile extends StatelessWidget {
  const _LeafTile({
    required this.leaf,
    required this.selected,
    required this.showParent,
    required this.enabled,
    required this.onTap,
  });

  final CategoryLeaf leaf;
  final bool selected;
  final bool showParent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = appColorFromHex(leaf.colorHex, fallback: colorScheme.primary);

    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.42)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
        onTap: enabled ? onTap : null,
        child: Semantics(
          button: true,
          selected: selected,
          label: showParent ? '${leaf.category.name} ${leaf.name}' : leaf.name,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.5)
                    : colorScheme.outlineVariant.withValues(alpha: 0.56),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: CategoryIconWidget(
                    leaf.iconName,
                    size: 15,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  leaf.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? color : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                if (showParent)
                  Text(
                    leaf.category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 9.5,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 全量叶子面板：搜索 + 按父分类分组的列表。
///
/// 分组标题可点 = 只记到父分类（父分类本身是一个合法选择）。
Future<CategoryLeaf?> showCategoryLeafSheet({
  required BuildContext context,
  required List<CategoryLeaf> leaves,
  MoneyCategoryUsage? usage,
  String? selectedKey,
  bool showParent = true,
}) {
  return showModalBottomSheet<CategoryLeaf>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _CategoryLeafSheet(
      leaves: leaves,
      usage: usage,
      selectedKey: selectedKey,
      showParent: showParent,
    ),
  );
}

class _CategoryLeafSheet extends StatefulWidget {
  const _CategoryLeafSheet({
    required this.leaves,
    required this.selectedKey,
    required this.showParent,
    this.usage,
  });

  final List<CategoryLeaf> leaves;
  final String? selectedKey;
  final bool showParent;
  final MoneyCategoryUsage? usage;

  @override
  State<_CategoryLeafSheet> createState() => _CategoryLeafSheetState();
}

class _CategoryLeafSheetState extends State<_CategoryLeafSheet> {
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyword = _keyword.toLowerCase();

    // 叶子名或父分类名命中都算匹配。
    final filtered = keyword.isEmpty
        ? widget.leaves
        : widget.leaves
              .where(
                (leaf) =>
                    leaf.name.toLowerCase().contains(keyword) ||
                    leaf.category.name.toLowerCase().contains(keyword),
              )
              .toList();

    // 分组顺序与组内顺序都用同一个「常用」比较器：分组标题按该组最靠前的
    // 叶子排序，组内叶子直接比。
    final catalogIndex = <String, int>{
      for (var i = 0; i < widget.leaves.length; i++) widget.leaves[i].key: i,
    };
    final groups = <String, List<CategoryLeaf>>{};
    final parents = <String, MoneyCategoryEntity>{};
    for (final leaf in filtered) {
      groups.putIfAbsent(leaf.categoryId, () => <CategoryLeaf>[]).add(leaf);
      parents[leaf.categoryId] = leaf.category;
    }
    for (final group in groups.values) {
      group.sort(
        (a, b) => compareLeavesByUsage(a, b, widget.usage, catalogIndex),
      );
    }
    final orderedGroups = groups.entries.toList()
      ..sort((left, right) {
        return compareLeavesByUsage(
          left.value.first,
          right.value.first,
          widget.usage,
          catalogIndex,
        );
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        color: colorScheme.surface,
        elevation: 18,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _searchController,
                  hintText: '搜索子分类 / 分类',
                  prefixIcon: const Icon(Icons.search_rounded, size: 19),
                  onChanged: (value) => setState(() => _keyword = value.trim()),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            '没有匹配的分类',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0,
                            ),
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final entry in orderedGroups) ...[
                              _GroupHeader(
                                category: parents[entry.key]!,
                                showTapHint: widget.showParent,
                                onTap: widget.showParent
                                    ? () => Navigator.of(context).pop(
                                        CategoryLeaf(
                                          category: parents[entry.key]!,
                                        ),
                                      )
                                    : null,
                              ),
                              for (final leaf in entry.value)
                                _LeafRow(
                                  leaf: leaf,
                                  selected: leaf.key == widget.selectedKey,
                                  onTap: () => Navigator.of(context).pop(leaf),
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.category,
    required this.onTap,
    required this.showTapHint,
  });

  final MoneyCategoryEntity category;
  final VoidCallback? onTap;
  final bool showTapHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = appColorFromHex(
      category.color,
      fallback: colorScheme.primary,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        children: [
          CategoryIconWidget(category.icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            category.name,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          if (showTapHint && onTap != null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('只记到这一类'),
            ),
        ],
      ),
    );
  }
}

class _LeafRow extends StatelessWidget {
  const _LeafRow({
    required this.leaf,
    required this.selected,
    required this.onTap,
  });

  final CategoryLeaf leaf;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = appColorFromHex(leaf.colorHex, fallback: colorScheme.primary);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 24),
      leading: CategoryIconWidget(leaf.iconName, size: 17, color: color),
      title: Text(
        leaf.name,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: color, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
