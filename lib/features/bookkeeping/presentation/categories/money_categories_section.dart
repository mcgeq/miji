import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_color_picker.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/categories/category_icon.dart';
import 'package:miji/features/bookkeeping/presentation/tags/money_tag_manager_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:flutter/services.dart';

class MoneyCategoriesSection extends ConsumerStatefulWidget {
  const MoneyCategoriesSection({super.key});

  @override
  ConsumerState<MoneyCategoriesSection> createState() =>
      _MoneyCategoriesSectionState();
}

class _MoneyCategoriesSectionState
    extends ConsumerState<MoneyCategoriesSection> {
  MoneyCategoryKind _kind = MoneyCategoryKind.expense;
  final _searchController = TextEditingController();
  String _keyword = '';

  /// 排序模式：列表变成可拖拽，顺序完全由用户决定。
  ///
  /// 管理页按 `sort_order` 显示（拖拽说了算）；记账表单里的叶子选择器仍然
  /// 按「常用」浮动（最近使用 → 次数 → 金额）。两个场景目的不同：
  /// 这里是「整理」，那里是「快选」。
  bool _reorderMode = false;
  bool _showDeleted = false;
  bool _savingOrder = false;

  /// 排序模式下的本地顺序（拖完立即生效，不等数据库流回传）。
  List<String>? _draftOrder;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(
      currentUserCategoryManagementCatalogProvider(_kind),
    );
    final usage = ref
        .watch(currentUserMonthCategoryUsageProvider(_kind))
        .maybeWhen(
          data: (value) => value,
          orElse: () => const MoneyCategoryUsage.empty(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // 左侧留白与右侧按钮等宽，保证分段控件在视觉上仍然居中。
            const SizedBox(width: 40),
            Expanded(
              child: Center(
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
            ),
            // 排序模式开关（拖拽调整顺序）。
            AppIconActionButton(
              tooltip: _reorderMode ? '退出排序' : '排序',
              onPressed: _reorderMode ? _exitReorderMode : _enterReorderMode,
              icon: Icons.swap_vert_rounded,
              variant: _reorderMode
                  ? AppIconActionVariant.filledTonal
                  : AppIconActionVariant.outlined,
            ),
            const SizedBox(width: 8),
            // 常驻新增入口。
            //
            // 原来的「新增分类」只存在于 categories 为空的 AppEmptyState 里，
            // 而种子数据总有分类，空态永远不会出现——用户因此永远无法新增分类。
            AppIconActionButton(
              tooltip: '标签管理',
              onPressed: () => _openTagManager(context),
              icon: Icons.label_rounded,
              variant: AppIconActionVariant.outlined,
            ),
            const SizedBox(width: 8),
            AppIconActionButton(
              tooltip: '新增分类',
              onPressed: () => _openCategoryDialog(context),
              icon: Icons.add_rounded,
              variant: AppIconActionVariant.filled,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_reorderMode)
          _ReorderHint(showDeletedCount: 0)
        else
          AppTextField(
            controller: _searchController,
            hintText: '搜索分类 / 子分类',
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            onChanged: (value) =>
                setState(() => _keyword = value.trim().toLowerCase()),
            suffixIcon: _keyword.isEmpty
                ? null
                : IconButton(
                    tooltip: '清除搜索',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _keyword = '');
                    },
                  ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: catalog.when(
            data: (catalog) => _buildCatalog(context, catalog, usage),
            loading: () => const AppSkeletonList(),
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

  Future<void> _openTagManager(BuildContext context) async {
    await showAppResponsiveDialog<void>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => const MoneyTagManagerDialog(),
    );
  }

  Widget _buildCatalog(
    BuildContext context,
    MoneyCategoryCatalog catalog,
    MoneyCategoryUsage usage,
  ) {
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

    final visible = _visibleCategories(catalog, usage);
    if (visible.isEmpty) {
      return AppEmptyState(
        title: '没有匹配的分类',
        message: '试试换个关键词。',
        icon: Icons.search_off_rounded,
        padding: EdgeInsets.zero,
        action: AppIconActionButton(
          tooltip: '清除搜索',
          onPressed: () {
            _searchController.clear();
            setState(() => _keyword = '');
          },
          icon: Icons.refresh_rounded,
          variant: AppIconActionVariant.outlined,
        ),
      );
    }

    final active = _orderedActive(visible);
    final deleted = visible.where((category) => category.isDeleted).toList();

    Widget buildTile(MoneyCategoryEntity category, {Widget? handle}) {
      return _CategoryTile(
        key: ValueKey<String>(category.id),
        category: category,
        subCategories: catalog.subCategoriesFor(category.id),
        usageMinor: usage.amountFor(category.id),
        usageShare: usage.shareFor(category.id),
        currencyCode: usage.currencyCode,
        showUsage: !usage.isEmpty,
        dragHandle: handle,
        onShowSubCategoryOrder: _activeSubCategoryCount(catalog, category) < 2
            ? null
            : () => _openSubCategoryOrderSheet(context, catalog, category),
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
        onEditSubCategory: (subCategory) =>
            _openSubCategoryDialog(context, category, subCategory: subCategory),
        onDeleteSubCategory: (subCategory) =>
            _setSubCategoryDeleted(context, subCategory, true),
        onRestoreSubCategory: (subCategory) =>
            _setSubCategoryDeleted(context, subCategory, false),
      );
    }

    if (_reorderMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 12),
              buildDefaultDragHandles: false,
              itemCount: active.length,
              // onReorderItem 已经替我们修正过 newIndex（旧 onReorder 需要
              // 自己在新旧位置之间做 +-1）。
              onReorderItem: (oldIndex, newIndex) =>
                  _onReorder(active, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final category = active[index];
                return Padding(
                  key: ValueKey<String>(category.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: buildTile(
                    category,
                    handle: ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.drag_indicator_rounded, size: 20),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _ReorderActions(
            busy: _savingOrder,
            onReset: () => _resetOrder(),
            onDone: _exitReorderMode,
          ),
        ],
      );
    }

    return RefreshIndicator(
      // 排序模式不做下拉刷新：拖拽与下拉手势会互相干扰。
      onRefresh: () => refreshMoneyData(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 18),
        children: [
          for (final category in active) ...[
            buildTile(category),
            const SizedBox(height: 10),
          ],
          if (deleted.isNotEmpty) ...[
            _DeletedSectionHeader(
              count: deleted.length,
              expanded: _showDeleted,
              onToggle: () => setState(() => _showDeleted = !_showDeleted),
            ),
            if (_showDeleted)
              for (final category in deleted) ...[
                const SizedBox(height: 10),
                buildTile(category),
              ],
          ],
        ],
      ),
    );
  }

  int _activeSubCategoryCount(
    MoneyCategoryCatalog catalog,
    MoneyCategoryEntity category,
  ) {
    return catalog
        .subCategoriesFor(category.id)
        .where((subCategory) => !subCategory.isDeleted)
        .length;
  }

  /// 在用分类，按 `sort_order`（拖拽模式下来自本地草稿顺序）。
  List<MoneyCategoryEntity> _orderedActive(List<MoneyCategoryEntity> visible) {
    final active = visible
        .where((category) => !category.isDeleted)
        .toList(growable: false);
    final draft = _draftOrder;
    if (!_reorderMode || draft == null) {
      return active;
    }
    final byId = {for (final category in active) category.id: category};
    final ordered = <MoneyCategoryEntity>[];
    for (final id in draft) {
      final category = byId.remove(id);
      if (category != null) {
        ordered.add(category);
      }
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  void _enterReorderMode() {
    _searchController.clear();
    setState(() {
      _reorderMode = true;
      _keyword = '';
      _draftOrder = null;
      _showDeleted = false;
    });
  }

  void _exitReorderMode() {
    setState(() {
      _reorderMode = false;
      _draftOrder = null;
    });
  }

  Future<void> _onReorder(
    List<MoneyCategoryEntity> active,
    int oldIndex,
    int newIndex,
  ) async {
    final ids = active.map((category) => category.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    // 落位触感：拖拽最需要「松手有反馈」。
    HapticFeedback.mediumImpact();
    setState(() => _draftOrder = ids);

    final userId = _currentUserId();
    if (userId == null) {
      _showMessage('请先登录');
      return;
    }
    setState(() => _savingOrder = true);
    try {
      await ref
          .read(moneyRepositoryProvider)
          .reorderCategories(userId, _kind, ids);
    } on MoneyRepositoryException {
      _showMessage('保存顺序失败');
      setState(() => _draftOrder = null);
    } finally {
      if (mounted) {
        setState(() => _savingOrder = false);
      }
    }
  }

  Future<void> _resetOrder() async {
    final userId = _currentUserId();
    if (userId == null) {
      _showMessage('请先登录');
      return;
    }
    setState(() => _savingOrder = true);
    try {
      await ref.read(moneyRepositoryProvider).resetCategoryOrder(userId, _kind);
      if (mounted) {
        setState(() => _draftOrder = null);
      }
    } on MoneyRepositoryException {
      _showMessage('恢复默认顺序失败');
    } finally {
      if (mounted) {
        setState(() => _savingOrder = false);
      }
    }
  }

  /// 搜索后的可见分类。
  ///
  /// 搜索同时匹配分类名与子分类名（「我那个『健身』子分类在哪个分类下面」
  /// 是真实场景）。顺序 = 仓储顺序（用量 → sort_order → name），管理页在
  /// 拖拽模式下由用户完全掌控。
  List<MoneyCategoryEntity> _visibleCategories(
    MoneyCategoryCatalog catalog,
    MoneyCategoryUsage usage,
  ) {
    final keyword = _keyword;
    final result = keyword.isEmpty
        ? List<MoneyCategoryEntity>.of(catalog.categories)
        : catalog.categories.where((category) {
            if (category.name.toLowerCase().contains(keyword)) {
              return true;
            }
            return catalog
                .subCategoriesFor(category.id)
                .any(
                  (subCategory) =>
                      subCategory.name.toLowerCase().contains(keyword),
                );
          }).toList();

    return result;
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
    await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransactionFormDialog(
        type: type,
        ledger: ledger,
        categoryId: category.id,
        subCategoryId: subCategory.id,
        showCategorySelector: false,
        onSubmit: (result) => _createFromCategoryForm(type, result),
      ),
    );
  }

  /// 返回错误文案（null = 成功）。
  Future<String?> _createFromCategoryForm(
    MoneyTransactionType type,
    Object result,
  ) async {
    if (result is! TransactionCreateFormResult) {
      return null;
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
      return null;
    } on MoneyRepositoryException {
      return '记录失败';
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

  /// 子分类排序面板。
  ///
  /// 子分类在主列表里是 Wrap 里的 chip，而「点 chip」= 快速记一笔，
  /// 长按拖动会与它抢手势；所以排序放到这个独立面板里用一列拖动，
  /// 命中区域更大、也不用引入 ReorderableWrap 依赖。
  Future<void> _openSubCategoryOrderSheet(
    BuildContext context,
    MoneyCategoryCatalog catalog,
    MoneyCategoryEntity category,
  ) async {
    final subCategories = catalog
        .subCategoriesFor(category.id)
        .where((subCategory) => !subCategory.isDeleted)
        .toList();
    final userId = _currentUserId();
    if (userId == null) {
      _showMessage('请先登录');
      return;
    }

    final changed = await showAppResponsiveDialog<bool>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => _SubCategoryOrderDialog(
        title: category.name,
        subCategories: subCategories,
      ),
    );
    if (changed != true || !mounted) {
      return;
    }

    final orderedIds = await ref
        .read(_subCategoryOrderDraftProvider.notifier)
        .read();
    try {
      await ref
          .read(moneyRepositoryProvider)
          .reorderSubCategories(userId, category.id, orderedIds);
    } on MoneyRepositoryException {
      _showMessage('保存子分类顺序失败');
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

/// 子分类排序面板里的临时顺序（弹窗与页面之间传递，避免把状态塞进弹窗的
/// Navigator 返回值里）。
final _subCategoryOrderDraftProvider =
    NotifierProvider<_SubCategoryOrderDraft, List<String>>(
      _SubCategoryOrderDraft.new,
    );

class _SubCategoryOrderDraft extends Notifier<List<String>> {
  @override
  List<String> build() => const <String>[];

  Future<List<String>> read() async => state;

  void set(List<String> ids) => state = ids;
}

class _SubCategoryOrderDialog extends ConsumerStatefulWidget {
  const _SubCategoryOrderDialog({
    required this.title,
    required this.subCategories,
  });

  final String title;
  final List<MoneySubCategoryEntity> subCategories;

  @override
  ConsumerState<_SubCategoryOrderDialog> createState() =>
      _SubCategoryOrderDialogState();
}

class _SubCategoryOrderDialogState
    extends ConsumerState<_SubCategoryOrderDialog> {
  late List<MoneySubCategoryEntity> _ordered;

  @override
  void initState() {
    super.initState();
    _ordered = List<MoneySubCategoryEntity>.of(widget.subCategories);
    ref
        .read(_subCategoryOrderDraftProvider.notifier)
        .set(_ordered.map((item) => item.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppDialogScaffold(
      title: '${widget.title} · 子分类顺序',
      subtitle: '按住手柄拖动',
      maxWidth: 460,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: SizedBox(
        height: 320,
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: _ordered.length,
          onReorderItem: (oldIndex, newIndex) {
            setState(() {
              final moved = _ordered.removeAt(oldIndex);
              _ordered.insert(newIndex, moved);
            });
            ref
                .read(_subCategoryOrderDraftProvider.notifier)
                .set(_ordered.map((item) => item.id).toList());
          },
          itemBuilder: (context, index) {
            final subCategory = _ordered[index];
            final color = appColorFromHex(
              subCategory.color,
              fallback: colorScheme.primary,
            );
            return ListTile(
              key: ValueKey<String>(subCategory.id),
              dense: true,
              contentPadding: const EdgeInsets.only(left: 4),
              leading: CategoryIconWidget(
                subCategory.icon,
                size: 18,
                color: color,
              ),
              title: Text(
                subCategory.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              trailing: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.drag_indicator_rounded, size: 20),
                ),
              ),
            );
          },
        ),
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(false),
        onConfirm: () => Navigator.of(context).pop(true),
        confirmTooltip: '保存顺序',
      ),
    );
  }
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    super.key,
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
    this.usageMinor = 0,
    this.usageShare = 0,
    this.currencyCode = 'CNY',
    this.showUsage = false,
    this.dragHandle,
    this.onShowSubCategoryOrder,
  });

  /// 排序模式下的拖拽手柄（显示在行首）。
  final Widget? dragHandle;

  /// 打开「子分类排序」面板。
  final VoidCallback? onShowSubCategoryOrder;

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

  /// 本月用量（来自统计模块的分类聚合）。
  final int usageMinor;
  final double usageShare;
  final String currencyCode;
  final bool showUsage;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  /// 子分类默认只显示 6 个：购物有 23 个子分类，整面铺开会让一张卡占掉半屏。
  static const _collapsedCount = 6;
  bool _expanded = false;

  MoneyCategoryEntity get category => widget.category;
  List<MoneySubCategoryEntity> get subCategories => widget.subCategories;
  int get usageMinor => widget.usageMinor;
  double get usageShare => widget.usageShare;
  String get currencyCode => widget.currencyCode;
  bool get showUsage => widget.showUsage;
  Widget? get dragHandle => widget.dragHandle;
  VoidCallback? get onShowSubCategoryOrder => widget.onShowSubCategoryOrder;
  VoidCallback? get onAddSubCategory => widget.onAddSubCategory;
  VoidCallback? get onEditCategory => widget.onEditCategory;
  VoidCallback? get onDeleteCategory => widget.onDeleteCategory;
  VoidCallback? get onRestoreCategory => widget.onRestoreCategory;
  ValueChanged<MoneySubCategoryEntity> get onTapSubCategory =>
      widget.onTapSubCategory;
  ValueChanged<MoneySubCategoryEntity> get onEditSubCategory =>
      widget.onEditSubCategory;
  ValueChanged<MoneySubCategoryEntity> get onDeleteSubCategory =>
      widget.onDeleteSubCategory;
  ValueChanged<MoneySubCategoryEntity> get onRestoreSubCategory =>
      widget.onRestoreSubCategory;

  /// 折叠时只展示前 N 个（重点是别再让「购物 23 个子分类」把页面拉成超长滚动）。
  List<MoneySubCategoryEntity> get _visibleSubCategories {
    if (_expanded || subCategories.length <= _collapsedCount) {
      return subCategories;
    }
    return subCategories.take(_collapsedCount).toList();
  }

  int get _hiddenSubCategoryCount =>
      _expanded ? 0 : (subCategories.length - _collapsedCount).clamp(0, 999);

  /// 本次构建时读到的隐私开关（_metaText 是 getter，拿不到 context）。
  bool _masked = false;

  /// 「8 个子分类 · 本月 ¥1,240 · 30.0%」。
  String get _metaText {
    final parts = <String>[
      '${subCategories.where((item) => !item.isDeleted).length} 个子分类',
    ];
    if (showUsage) {
      parts.add(
        maskedMoneyOr(
          '本月 ${formatMoneyMinor(usageMinor, currencyCode)}',
          _masked,
        ),
      );
      if (usageMinor > 0) {
        parts.add('${(usageShare * 100).toStringAsFixed(1)}%');
      }
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = _colorFromHex(category.color) ?? colorScheme.primary;
    final opacity = category.isDeleted ? 0.56 : 1.0;
    _masked = MoneyPrivacy.of(context);

    return Opacity(
      opacity: opacity,
      child: AppListItemPanel(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (dragHandle != null) ...[
                  dragHandle!,
                  const SizedBox(width: 2),
                ],
                AppListItemIcon(
                  icon:
                      materialIconForCategoryIcon(category.icon) ??
                      Icons.category_rounded,
                  color: color,
                ),
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
                        _metaText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                      if (showUsage) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: usageShare.clamp(0.0, 1.0),
                            minHeight: 5,
                            color: color,
                            backgroundColor: color.withValues(alpha: 0.14),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onShowSubCategoryOrder != null)
                  AppIconActionButton(
                    tooltip: '子分类排序',
                    onPressed: onShowSubCategoryOrder,
                    icon: Icons.reorder_rounded,
                    variant: AppIconActionVariant.outlined,
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
                  for (final subCategory in _visibleSubCategories)
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
                  if (_hiddenSubCategoryCount > 0)
                    _SubCategoryMoreChip(
                      count: _hiddenSubCategoryCount,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _expanded = true);
                      },
                    ),
                  if (_expanded && subCategories.length > _collapsedCount)
                    _SubCategoryMoreChip(
                      label: '收起',
                      count: 0,
                      onTap: () => setState(() => _expanded = false),
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

/// 排序模式提示：顺序只影响管理页，记账表单仍把常用的排前面。
class _ReorderHint extends StatelessWidget {
  const _ReorderHint({required this.showDeletedCount});

  final int showDeletedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pan_tool_alt_rounded,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '按住右侧手柄拖动调整顺序。这是你整理出的顺序；记账页仍会把常用的分类排前面。',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 排序模式的底部操作条。
class _ReorderActions extends StatelessWidget {
  const _ReorderActions({
    required this.busy,
    required this.onReset,
    required this.onDone,
  });

  final bool busy;
  final VoidCallback onReset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: busy ? null : onReset,
            icon: const Icon(Icons.restart_alt_rounded, size: 17),
            label: const Text('恢复默认顺序'),
          ),
          const Spacer(),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          FilledButton(
            onPressed: busy ? null : onDone,
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}

/// 「已停用 N 个」折叠区头。停用分类不参与拖拽排序，语义最简单。
class _DeletedSectionHeader extends StatelessWidget {
  const _DeletedSectionHeader({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int count;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.visibility_off_rounded,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '已停用 $count 个',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Icon(
                expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「+17 个」/「收起」胶囊。
class _SubCategoryMoreChip extends StatelessWidget {
  const _SubCategoryMoreChip({
    required this.count,
    required this.onTap,
    this.label,
  });

  final int count;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(theme.radiusTokens.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.radiusTokens.md),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                label == null ? Icons.add_rounded : Icons.expand_less_rounded,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label ?? '+$count 个',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
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
              CategoryIconWidget(
                subCategory.icon,
                size: 15,
                color: color,
                fallback: Icons.label_rounded,
              ),
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
