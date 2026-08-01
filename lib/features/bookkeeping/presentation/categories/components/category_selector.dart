import 'package:flutter/material.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';

class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.catalog,
    required this.selectedCategoryId,
    required this.selectedSubCategoryId,
    required this.onChanged,
    this.showSubCategory = true,
    this.categoryLabelText = '分类',
    this.subCategoryLabelText = '子分类',
    this.emptyCategoryText = '暂无可选分类',
    this.emptySubCategoryText = '暂无子分类',
    this.enabled = true,
    this.allowClear = false,
    this.clearCategoryLabel = '不限分类',
    this.enableFilter = true,
  });

  final MoneyCategoryCatalog catalog;
  final String? selectedCategoryId;
  final String? selectedSubCategoryId;
  final ValueChanged<MoneyCategorySelection> onChanged;
  final bool showSubCategory;
  final String categoryLabelText;
  final String subCategoryLabelText;
  final String emptyCategoryText;
  final String emptySubCategoryText;
  final bool enabled;
  final bool allowClear;
  final String clearCategoryLabel;
  final bool enableFilter;

  @override
  Widget build(BuildContext context) {
    final selectedCategory = catalog.categoryById(selectedCategoryId);
    final subCategories = selectedCategory == null
        ? const <MoneySubCategoryEntity>[]
        : catalog.subCategoriesFor(selectedCategory.id);
    final selectedSubCategory = _selectedSubCategory(
      subCategories,
      selectedSubCategoryId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormDropdown<String>(
          initialSelection: selectedCategory?.id ?? (allowClear ? '' : null),
          label: categoryLabelText,
          helperText: catalog.categories.isEmpty ? emptyCategoryText : null,
          leadingIcon: const Icon(Icons.category_rounded),
          enabled: enabled && (catalog.categories.isNotEmpty || allowClear),
          enableFilter: enableFilter,
          onSelected: (categoryId) {
            if (categoryId == null || categoryId.isEmpty) {
              onChanged(
                const MoneyCategorySelection(category: null, subCategory: null),
              );
              return;
            }
            final category = catalog.categoryById(categoryId);
            onChanged(
              MoneyCategorySelection(category: category, subCategory: null),
            );
          },
          entries: [
            if (allowClear)
              DropdownMenuEntry(
                value: '',
                label: clearCategoryLabel,
                labelWidget: _ClearCategorySelectorItem(
                  label: clearCategoryLabel,
                ),
              ),
            ...catalog.categories.map(
              (category) => DropdownMenuEntry(
                value: category.id,
                label: category.name,
                labelWidget: _CategorySelectorItem(category: category),
              ),
            ),
          ],
        ),
        if (showSubCategory) ...[
          const SizedBox(height: 12),
          FormDropdown<String>(
            initialSelection: selectedSubCategory?.id,
            label: subCategoryLabelText,
            leadingIcon: const Icon(Icons.sell_rounded),
            enabled:
                enabled && selectedCategory != null && subCategories.isNotEmpty,
            enableFilter: enableFilter,
            onSelected: (subCategoryId) {
              final subCategory = catalog.subCategoryById(subCategoryId);
              onChanged(
                MoneyCategorySelection(
                  category: selectedCategory,
                  subCategory: subCategory,
                ),
              );
            },
            entries: subCategories
                .map(
                  (subCategory) => DropdownMenuEntry(
                    value: subCategory.id,
                    label: subCategory.name,
                    labelWidget: _SubCategorySelectorItem(
                      subCategory: subCategory,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  MoneySubCategoryEntity? _selectedSubCategory(
    List<MoneySubCategoryEntity> subCategories,
    String? subCategoryId,
  ) {
    if (subCategoryId == null) {
      return null;
    }

    for (final subCategory in subCategories) {
      if (subCategory.id == subCategoryId) {
        return subCategory;
      }
    }
    return null;
  }
}

class _CategorySelectorItem extends StatelessWidget {
  const _CategorySelectorItem({required this.category});

  final MoneyCategoryEntity category;

  @override
  Widget build(BuildContext context) {
    return _SelectorItem(
      icon: category.icon,
      label: category.name,
      fallbackIcon: Icons.category_rounded,
    );
  }
}

class _ClearCategorySelectorItem extends StatelessWidget {
  const _ClearCategorySelectorItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _SelectorItem(
      icon: null,
      label: label,
      fallbackIcon: Icons.all_inclusive_rounded,
    );
  }
}

class _SubCategorySelectorItem extends StatelessWidget {
  const _SubCategorySelectorItem({required this.subCategory});

  final MoneySubCategoryEntity subCategory;

  @override
  Widget build(BuildContext context) {
    return _SelectorItem(
      icon: subCategory.icon,
      label: subCategory.name,
      fallbackIcon: Icons.sell_rounded,
    );
  }
}

class _SelectorItem extends StatelessWidget {
  const _SelectorItem({
    required this.icon,
    required this.label,
    required this.fallbackIcon,
  });

  final String? icon;
  final String label;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconText = icon?.trim();

    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Center(
            child: iconText == null || iconText.isEmpty
                ? Icon(fallbackIcon, size: 18, color: colorScheme.primary)
                : Text(
                    iconText,
                    overflow: TextOverflow.clip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      letterSpacing: 0,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
          ),
        ),
      ],
    );
  }
}
