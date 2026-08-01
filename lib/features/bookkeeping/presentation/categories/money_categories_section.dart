import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_color_picker.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

class MoneyCategoriesSection extends ConsumerStatefulWidget {
  const MoneyCategoriesSection({super.key});

  @override
  ConsumerState<MoneyCategoriesSection> createState() =>
      _MoneyCategoriesSectionState();
}

class _MoneyCategoriesSectionState
    extends ConsumerState<MoneyCategoriesSection> {
  MoneyCategoryKind _kind = MoneyCategoryKind.expense;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(
      currentUserCategoryManagementCatalogProvider(_kind),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: AppSlidingSegmentedControl<MoneyCategoryKind>(
            minSegmentWidth: 72,
            value: _kind,
            onChanged: (value) => setState(() => _kind = value),
            segments: const [
              AppSlidingSegment(
                value: MoneyCategoryKind.expense,
                icon: Icons.trending_down_rounded,
                label: '支出',
              ),
              AppSlidingSegment(
                value: MoneyCategoryKind.income,
                icon: Icons.trending_up_rounded,
                label: '收入',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: catalog.when(
            data: (catalog) => _buildCatalog(context, catalog),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => AppErrorState(
              title: '读取分类失败',
              onRetry: () => ref.invalidate(
                currentUserCategoryManagementCatalogProvider(_kind),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCatalog(BuildContext context, MoneyCategoryCatalog catalog) {
    if (catalog.categories.isEmpty) {
      return AppEmptyState(
        title: '暂无分类',
        message: '新增分类后可以继续管理子分类和颜色。',
        icon: Icons.category_rounded,
        padding: EdgeInsets.zero,
        action: AppIconActionButton(
          tooltip: '新增分类',
          onPressed: () => _openCategoryDialog(context),
          icon: Icons.add_rounded,
          variant: AppIconActionVariant.filled,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 18),
      itemCount: catalog.categories.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final category = catalog.categories[index];
        return _CategoryTile(
          category: category,
          subCategories: catalog.subCategoriesFor(category.id),
          onAddSubCategory: category.isDeleted
              ? null
              : () => _openSubCategoryDialog(context, category),
          onEditCategory: category.isSystem || category.isDeleted
              ? null
              : () => _openCategoryDialog(context, category: category),
          onDeleteCategory: category.isSystem || category.isDeleted
              ? null
              : () => _setCategoryDeleted(context, category, true),
          onRestoreCategory: category.isSystem || !category.isDeleted
              ? null
              : () => _setCategoryDeleted(context, category, false),
          onTapSubCategory: (subCategory) =>
              _openSubCategoryTransaction(context, category, subCategory),
          onEditSubCategory: (subCategory) => _openSubCategoryDialog(
            context,
            category,
            subCategory: subCategory,
          ),
          onDeleteSubCategory: (subCategory) =>
              _setSubCategoryDeleted(context, subCategory, true),
          onRestoreSubCategory: (subCategory) =>
              _setSubCategoryDeleted(context, subCategory, false),
        );
      },
    );
  }

  Future<void> _openCategoryDialog(
    BuildContext context, {
    MoneyCategoryEntity? category,
  }) async {
    final result = await showAppResponsiveDialog<_CategoryFormData>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => _CategoryFormDialog(
        title: category == null ? '新增分类' : '编辑分类',
        initialName: category?.name,
        initialColor: category?.color ?? _defaultColorForKind(_kind),
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    final userId = _currentUserId();
    if (userId == null) {
      _showMessage('请先登录');
      return;
    }

    try {
      final repository = ref.read(moneyRepositoryProvider);
      if (category == null) {
        await repository.createCategory(
          userId,
          MoneyCategoryDraft(
            name: result.name,
            kind: _kind,
            color: result.color,
            icon: _kind == MoneyCategoryKind.expense
                ? 'category'
                : 'trending_up',
          ),
        );
      } else {
        await repository.updateCategory(
          userId,
          MoneyCategoryUpdate(
            id: category.id,
            name: result.name,
            color: result.color,
            icon: category.icon,
          ),
        );
      }
    } on MoneyRepositoryException {
      _showMessage('保存分类失败');
    }
  }

  Future<void> _openSubCategoryDialog(
    BuildContext context,
    MoneyCategoryEntity category, {
    MoneySubCategoryEntity? subCategory,
  }) async {
    if (subCategory != null && subCategory.isDeleted) {
      return;
    }
    final result = await showAppResponsiveDialog<_CategoryFormData>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => _CategoryFormDialog(
        title: subCategory == null ? '新增子分类' : '编辑子分类',
        initialName: subCategory?.name,
        initialColor:
            subCategory?.color ?? category.color ?? _defaultColorForKind(_kind),
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    final userId = _currentUserId();
    if (userId == null) {
      _showMessage('请先登录');
      return;
    }

    try {
      final repository = ref.read(moneyRepositoryProvider);
      if (subCategory == null) {
        await repository.createSubCategory(
          userId,
          MoneySubCategoryDraft(
            categoryId: category.id,
            name: result.name,
            kind: category.kind,
            color: result.color,
            icon: 'label',
          ),
        );
      } else {
        await repository.updateSubCategory(
          userId,
          MoneySubCategoryUpdate(
            id: subCategory.id,
            name: result.name,
            color: result.color,
            icon: subCategory.icon,
          ),
        );
      }
    } on MoneyRepositoryException {
      _showMessage('保存子分类失败');
    }
  }

  Future<void> _setCategoryDeleted(
    BuildContext context,
    MoneyCategoryEntity category,
    bool deleted,
  ) async {
    final userId = _currentUserId();
    if (userId == null) {
      _showMessage('请先登录');
      return;
    }

    try {
      final repository = ref.read(moneyRepositoryProvider);
      if (deleted) {
        await repository.deleteCategory(userId, category.id);
      } else {
        await repository.restoreCategory(userId, category.id);
      }
    } on MoneyRepositoryException {
      _showMessage(deleted ? '停用分类失败' : '恢复分类失败');
    }
  }

  Future<void> _openSubCategoryTransaction(
    BuildContext context,
    MoneyCategoryEntity category,
    MoneySubCategoryEntity subCategory,
  ) async {
    if (category.isDeleted || subCategory.isDeleted) {
      return;
    }

    final type = category.kind == MoneyCategoryKind.income
        ? MoneyTransactionType.income
        : MoneyTransactionType.expense;
    final ledger = ref.read(currentUserEffectiveTransactionLedgerValueProvider);
    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransactionFormDialog(
        type: type,
        ledger: ledger,
        categoryId: category.id,
        subCategoryId: subCategory.id,
        showCategorySelector: false,
      ),
    );
    if (!mounted || result is! TransactionCreateFormResult) {
      return;
    }

    try {
      final splitConfig = result.splitConfig;
      if (splitConfig == null) {
        await ref
            .read(currentUserMoneyTransactionActionsProvider)
            .createTransaction(result.draft);
      } else {
        await ref
            .read(currentUserMoneyTransactionActionsProvider)
            .createTransactionWithSplit(result.draft, splitConfig);
      }
      _showMessage('已记录');
    } on MoneyRepositoryException {
      _showMessage('记录失败');
    }
  }

  Future<void> _setSubCategoryDeleted(
    BuildContext context,
    MoneySubCategoryEntity subCategory,
    bool deleted,
  ) async {
    final userId = _currentUserId();
    if (userId == null) {
      _showMessage('请先登录');
      return;
    }

    try {
      final repository = ref.read(moneyRepositoryProvider);
      if (deleted) {
        await repository.deleteSubCategory(userId, subCategory.id);
      } else {
        await repository.restoreSubCategory(userId, subCategory.id);
      }
    } on MoneyRepositoryException {
      _showMessage(deleted ? '停用子分类失败' : '恢复子分类失败');
    }
  }

  String? _currentUserId() {
    final session = ref.read(authSessionControllerProvider);
    return session.isUnlocked ? session.userId : null;
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.subCategories,
    required this.onAddSubCategory,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onRestoreCategory,
    required this.onTapSubCategory,
    required this.onEditSubCategory,
    required this.onDeleteSubCategory,
    required this.onRestoreSubCategory,
  });

  final MoneyCategoryEntity category;
  final List<MoneySubCategoryEntity> subCategories;
  final VoidCallback? onAddSubCategory;
  final VoidCallback? onEditCategory;
  final VoidCallback? onDeleteCategory;
  final VoidCallback? onRestoreCategory;
  final ValueChanged<MoneySubCategoryEntity> onTapSubCategory;
  final ValueChanged<MoneySubCategoryEntity> onEditSubCategory;
  final ValueChanged<MoneySubCategoryEntity> onDeleteSubCategory;
  final ValueChanged<MoneySubCategoryEntity> onRestoreSubCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = _colorFromHex(category.color) ?? colorScheme.primary;
    final opacity = category.isDeleted ? 0.56 : 1.0;

    return Opacity(
      opacity: opacity,
      child: AppListItemPanel(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppListItemIcon(icon: Icons.category_rounded, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (category.isSystem)
                            const AppBadge(label: '系统')
                          else if (category.isDeleted)
                            const AppBadge(label: '已停用'),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${subCategories.where((item) => !item.isDeleted).length} 个子分类',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                AppIconActionButton(
                  tooltip: '新增子分类',
                  onPressed: onAddSubCategory,
                  icon: Icons.add_rounded,
                  variant: AppIconActionVariant.outlined,
                ),
                if (onEditCategory != null)
                  AppIconActionButton(
                    tooltip: '编辑分类',
                    onPressed: onEditCategory,
                    icon: Icons.edit_rounded,
                    variant: AppIconActionVariant.outlined,
                  ),
                if (onDeleteCategory != null)
                  AppIconActionButton(
                    tooltip: '停用分类',
                    onPressed: onDeleteCategory,
                    icon: Icons.block_rounded,
                    variant: AppIconActionVariant.outlined,
                  ),
                if (onRestoreCategory != null)
                  AppIconActionButton(
                    tooltip: '恢复分类',
                    onPressed: onRestoreCategory,
                    icon: Icons.restore_rounded,
                    variant: AppIconActionVariant.outlined,
                  ),
              ],
            ),
            if (subCategories.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final subCategory in subCategories)
                    _SubCategoryChip(
                      subCategory: subCategory,
                      color: _colorFromHex(subCategory.color) ?? color,
                      onTap: subCategory.isDeleted
                          ? null
                          : () => onTapSubCategory(subCategory),
                      onEdit: subCategory.isSystem || subCategory.isDeleted
                          ? null
                          : () => onEditSubCategory(subCategory),
                      onDelete: subCategory.isSystem || subCategory.isDeleted
                          ? null
                          : () => onDeleteSubCategory(subCategory),
                      onRestore: subCategory.isSystem || !subCategory.isDeleted
                          ? null
                          : () => onRestoreSubCategory(subCategory),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubCategoryChip extends StatelessWidget {
  const _SubCategoryChip({
    required this.subCategory,
    required this.color,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final MoneySubCategoryEntity subCategory;
  final Color color;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(theme.radiusTokens.md),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: subCategory.isDeleted
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.52)
              : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(theme.radiusTokens.md),
          border: Border.all(
            color: subCategory.isDeleted
                ? colorScheme.outlineVariant.withValues(alpha: 0.42)
                : color.withValues(alpha: 0.22),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.label_rounded, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                subCategory.name,
                style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 0),
              ),
              if (subCategory.isDeleted) ...[
                const SizedBox(width: 6),
                Text(
                  '已停用',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
              if (onEdit != null) ...[
                const SizedBox(width: 4),
                _MiniIconButton(
                  tooltip: '编辑子分类',
                  icon: Icons.edit_rounded,
                  onPressed: onEdit!,
                ),
              ],
              if (onDelete != null)
                _MiniIconButton(
                  tooltip: '停用子分类',
                  icon: Icons.block_rounded,
                  onPressed: onDelete!,
                ),
              if (onRestore != null)
                _MiniIconButton(
                  tooltip: '恢复子分类',
                  icon: Icons.restore_rounded,
                  onPressed: onRestore!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  const _MiniIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 15),
        ),
      ),
    );
  }
}

class _CategoryFormData {
  const _CategoryFormData({required this.name, required this.color});

  final String name;
  final String color;
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({
    required this.title,
    required this.initialColor,
    this.initialName,
  });

  final String title;
  final String? initialName;
  final String initialColor;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedColor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _selectedColor = widget.initialColor;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: widget.title,
      maxWidth: 420,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: Form(
        key: _formKey,
        child: AppFormColumn(
          children: [
            AppTextFormField(
              controller: _nameController,
              autofocus: true,
              labelText: '名称',
              prefixIcon: const Icon(Icons.category_rounded),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入名称';
                }
                return null;
              },
            ),
            AppColorPickerField(
              title: '颜色',
              selectedColor: _selectedColor,
              onSelected: (color) => setState(() => _selectedColor = color),
            ),
          ],
        ),
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: '保存',
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      _CategoryFormData(
        name: _nameController.text.trim(),
        color: _selectedColor,
      ),
    );
  }
}

Color? _colorFromHex(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final normalized = value.startsWith('#') ? value.substring(1) : value;
  if (normalized.length != 6) {
    return null;
  }
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(0xFF000000 | parsed);
}

String _defaultColorForKind(MoneyCategoryKind kind) {
  return switch (kind) {
    MoneyCategoryKind.expense => '#EF4444',
    MoneyCategoryKind.income => '#22C55E',
  };
}
