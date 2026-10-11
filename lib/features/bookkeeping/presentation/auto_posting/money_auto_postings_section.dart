import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_field_style.dart';
import 'package:miji/core/presentation/components/app_form_hint.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/presentation/auto_posting/auto_posting_conflict_sheet.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_auto_posting_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_selector.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

class MoneyAutoPostingsSection extends ConsumerStatefulWidget {
  const MoneyAutoPostingsSection({super.key, this.onOpenInstallments});

  /// 切到「分期」面板。
  ///
  /// 列表底部那条「相关」链接用它跳转——分期还款计划的数据与入口只保留
  /// 分期 Tab 一份，这里不再自己维护一份预览。
  final VoidCallback? onOpenInstallments;

  @override
  ConsumerState<MoneyAutoPostingsSection> createState() =>
      _MoneyAutoPostingsSectionState();
}

class _MoneyAutoPostingsSectionState
    extends ConsumerState<MoneyAutoPostingsSection> {
  FToast? _toast;
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(currentUserAutoPostingTemplatesProvider);
    final currentLedger = ref.watch(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const AsyncValue<List<MoneyAccountEntity>>.data(
            <MoneyAccountEntity>[],
          )
        : ref.watch(currentUserMoneyLedgerAccountsProvider(currentLedger.id));
    final expenseCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
    );
    final incomeCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.income),
    );
    final accountRows = accounts.asData?.value ?? const <MoneyAccountEntity>[];
    final expenseCategories =
        expenseCatalog.asData?.value ?? const MoneyCategoryCatalog.empty();
    final incomeCategories =
        incomeCatalog.asData?.value ?? const MoneyCategoryCatalog.empty();
    // 只用来决定列表底部那条「相关」链接显示什么，不参与任何金额计算。
    final activePlanCount = ref
        .watch(currentUserInstallmentPlansProvider)
        .maybeWhen(
          data: (items) => items.where((plan) => plan.isActive).length,
          orElse: () => 0,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        AppTextField(
          controller: _searchController,
          hintText: '搜索模板名称 / 描述',
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
        const SizedBox(height: 10),
        // 冲突与接管失效合并成一行，默认折叠。两者都是「提醒」，不是页面主体；
        // 分开铺开时任意两层同时出现就能把模板列表顶出首屏。
        _AutoPostingAttentionPanel(
          onOpenConflicts: () => showAutoPostingConflictSheet(context),
          onReleaseStale: (items) => _confirmReleaseStaleTakeOver(items),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: AppIconActionButton(
            tooltip: '新增自动记账',
            onPressed: currentLedger == null
                ? null
                : () => _openTemplateDialog(),
            // 与账户 / 预算 / 分期三页的页面级新增入口保持同一图标与样式。
            icon: Icons.add_rounded,
            variant: AppIconActionVariant.filled,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: templates.when(
            data: (items) {
              if (currentLedger == null) {
                return const AppEmptyState(
                  title: '请先选择账本',
                  message: '自动记账模板会保存到当前账本。',
                  icon: Icons.menu_book_rounded,
                );
              }
              if (items.isEmpty) {
                return AppEmptyState(
                  title: '暂无自动记账模板',
                  message: '可以添加房贷、车贷、会员订阅等固定流水。',
                  icon: Icons.event_repeat_rounded,
                  action: FilledButton.icon(
                    onPressed: () => _openTemplateDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('新增自动记账'),
                  ),
                );
              }

              final visibleItems = _keyword.isEmpty
                  ? items
                  : items.where((item) {
                      final haystack = [
                        item.name,
                        item.description,
                        item.merchant,
                        item.notes,
                      ].join(' ').toLowerCase();
                      return haystack.contains(_keyword);
                    }).toList();
              if (visibleItems.isEmpty) {
                return const AppEmptyState(title: '没有匹配的模板');
              }
              return RefreshIndicator(
                onRefresh: () => refreshMoneyData(ref),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount:
                      visibleItems.length + (activePlanCount > 0 ? 1 : 0),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == visibleItems.length) {
                      return _RelatedInstallmentsLink(
                        count: activePlanCount,
                        onTap: widget.onOpenInstallments,
                      );
                    }
                    final template = visibleItems[index];
                    return _AutoPostingTemplateCard(
                      template: template,
                      account: _accountById(accountRows, template.accountId),
                      categoryText: _categoryText(
                        template,
                        expenseCategories,
                        incomeCategories,
                      ),
                      onEdit: () => _openTemplateDialog(template),
                      onDelete: () => _confirmDelete(template),
                      onRunNow: () => _runTemplateNow(template),
                      onReleaseTakeOver: () =>
                          _confirmReleaseTakeOver(template),
                    );
                  },
                ),
              );
            },
            loading: () => const AppSkeletonList(),
            error: (error, stackTrace) => AppErrorState(
              title: '读取自动记账失败',
              onRetry: () =>
                  ref.invalidate(currentUserAutoPostingTemplatesProvider),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openTemplateDialog([
    MoneyAutoPostingTemplateEntity? template,
  ]) async {
    final result = await showAppResponsiveDialog<_AutoPostingFormResult>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => _AutoPostingFormDialog(template: template),
    );
    if (result == null || !mounted) {
      return;
    }

    try {
      final actions = ref.read(currentUserMoneyAutoPostingActionsProvider);
      final saved = template == null
          ? await actions.createTemplate(result.toDraft())
          : await actions.updateTemplate(result.toUpdate(template));
      if (!mounted) return;
      AppToast.success(
        _ensureToast(),
        context,
        template == null ? '自动记账模板已创建' : '自动记账模板已更新',
      );
      if (saved.isActive) {
        await _warnIfConflicting(saved.id);
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  /// 刚保存的模板如果跟某个分期撞车，立刻问一句。
  ///
  /// 放在保存之后而不是之前：冲突判定要展开 occurrence，需要完整的模板数据，
  /// 表单里的草稿拿不到稳定 id。晚一步问，但问的是确定的事。
  Future<void> _warnIfConflicting(String templateId) async {
    ref.invalidate(currentUserAutoPostingInstallmentConflictsProvider);
    final conflicts = await ref.read(
      currentUserAutoPostingInstallmentConflictsProvider.future,
    );
    final hit = conflicts
        .where((item) => item.templateId == templateId)
        .toList(growable: false);
    if (hit.isEmpty || !mounted) {
      return;
    }

    final conflict = hit.first;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '可能与分期重复',
      message:
          '“${conflict.templateName}”与分期“${conflict.planName}”'
          '第 ${conflict.periodNumber} 期看起来是同一笔还款，'
          '两个都留着会在到期日记两遍账。现在交给分期记账吗？'
          '（模板会被停用，可随时恢复）',
      confirmLabel: '交给分期',
      cancelLabel: '暂不处理',
      icon: Icons.warning_amber_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyAutoPostingActionsProvider)
          .takeOverByInstallment(conflict.templateId, conflict.planId);
      if (!mounted) return;
      AppToast.success(
        _ensureToast(),
        context,
        '已交给分期「${conflict.planName}」记账',
      );
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _runTemplateNow(MoneyAutoPostingTemplateEntity template) async {
    try {
      final summary = await ref
          .read(currentUserMoneyAutoPostingActionsProvider)
          .runTemplateNow(template.id);
      if (!mounted) return;
      final parts = <String>[
        if (summary.postedCount > 0) '入账 ${summary.postedCount} 笔',
        if (summary.skippedCount > 0) '跳过 ${summary.skippedCount} 个未到期',
        if (summary.blockedCount > 0) '拦截 ${summary.blockedCount} 笔',
        if (summary.failedCount > 0) '失败 ${summary.failedCount} 笔',
      ];
      if (parts.isEmpty) {
        AppToast.success(_ensureToast(), context, '${template.name}：当前没有待执行条目');
      } else {
        AppToast.success(
          _ensureToast(),
          context,
          '${template.name}：${parts.join('，')}',
        );
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _confirmDelete(MoneyAutoPostingTemplateEntity template) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除自动记账',
      message: '确认删除“${template.name}”？已经生成的流水不会被删除。',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyAutoPostingActionsProvider)
          .deleteTemplate(template.id);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '自动记账模板已删除');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _confirmReleaseStaleTakeOver(
    List<MoneyAutoPostingTemplateEntity> templates,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '恢复独立入账',
      message:
          '这些模板对应的分期已经取消或还完。'
          '恢复后它们会重新开始记账——确认这些支出现在还需要记吗？',
      confirmLabel: '全部恢复',
      icon: Icons.link_off_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      final actions = ref.read(currentUserMoneyAutoPostingActionsProvider);
      for (final template in templates) {
        await actions.releaseTakeOver(template.id);
      }
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '已恢复 ${templates.length} 个模板');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _confirmReleaseTakeOver(
    MoneyAutoPostingTemplateEntity template,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '恢复独立入账',
      message:
          '确认让“${template.name}”重新自己记账？'
          '如果对应的分期还在，这一笔就会被记两遍。',
      confirmLabel: '恢复',
      icon: Icons.event_repeat_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyAutoPostingActionsProvider)
          .releaseTakeOver(template.id);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '已恢复独立入账');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  String _errorText(Object error) {
    if (error is MoneyRepositoryException) {
      return switch (error.code) {
        MoneyRepositoryErrorCode.invalidTransactionAmount => '金额必须大于 0',
        MoneyRepositoryErrorCode.accountNotFound => '账户不可用',
        MoneyRepositoryErrorCode.categoryNotFound => '分类不可用',
        MoneyRepositoryErrorCode.ledgerNotFound => '账本不可用',
        MoneyRepositoryErrorCode.autoPostingTemplateNotFound => '模板不可用',
        MoneyRepositoryErrorCode.invalidTransferAccounts => '自动记账仅支持收入或支出',
        MoneyRepositoryErrorCode.invalidInstallmentTakeOver => '币种不一致，无法交给该分期',
        MoneyRepositoryErrorCode.databaseReadFailed => '读取失败',
        MoneyRepositoryErrorCode.databaseWriteFailed => '保存失败',
        _ => '操作失败',
      };
    }
    return '操作失败';
  }
}

/// 顶部提醒区：冲突登记 + 接管失效合并成一行，默认折叠。
///
/// 原来这里是两层独立横幅（都常驻展开），再加上列表上方的分期预览，三层
/// 同时出现时模板列表首屏基本看不见。现在只有真的「需要处理」时才占位，
/// 且折叠成一行；展开才铺出具体条目。
///
/// 「接管失效」刻意**不自动恢复**模板：分期还完的同一个月突然冒出一笔自动
/// 记账，用户会以为系统凭空造了一笔账。必须让他自己点头。
class _AutoPostingAttentionPanel extends ConsumerStatefulWidget {
  const _AutoPostingAttentionPanel({
    required this.onOpenConflicts,
    required this.onReleaseStale,
  });

  final VoidCallback onOpenConflicts;
  final ValueChanged<List<MoneyAutoPostingTemplateEntity>> onReleaseStale;

  @override
  ConsumerState<_AutoPostingAttentionPanel> createState() =>
      _AutoPostingAttentionPanelState();
}

class _AutoPostingAttentionPanelState
    extends ConsumerState<_AutoPostingAttentionPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final conflictCount = ref
        .watch(currentUserAutoPostingInstallmentConflictsProvider)
        .maybeWhen(data: (items) => items.length, orElse: () => 0);
    final templates = ref
        .watch(currentUserAutoPostingTemplatesProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => const <MoneyAutoPostingTemplateEntity>[],
        );
    final plans = ref
        .watch(currentUserInstallmentPlansProvider)
        .maybeWhen(
          data: (items) => items,
          orElse: () => const <MoneyInstallmentPlanEntity>[],
        );
    // 分期取消 / 还完之后，接管就失效了，模板却还停在停用状态。
    final stale = templates
        .where((template) {
          final planId = template.takenOverByPlanId;
          if (planId == null) {
            return false;
          }
          return !plans.any((plan) => plan.id == planId && plan.isActive);
        })
        .toList(growable: false);
    final total = conflictCount + stale.length;
    if (total == 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radiusTokens = theme.radiusTokens;
    final kinds = <String>[
      if (conflictCount > 0) '重复登记',
      if (stale.isNotEmpty) '接管失效',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.errorContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(radiusTokens.md),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '需要处理 $total 项',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Text(
                      kinds.join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 展开体走 AnimatedSize：原来是硬分支，面板高度瞬跳。
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Column(
                        children: [
                          if (conflictCount > 0)
                            _AutoPostingAttentionRow(
                              icon: Icons.copy_all_rounded,
                              text:
                                  '检测到 $conflictCount 处重复登记，'
                                  '同一笔还款会被记两遍账',
                              actionLabel: '去处理',
                              actionColor: colorScheme.error,
                              onAction: widget.onOpenConflicts,
                            ),
                          if (stale.isNotEmpty)
                            _AutoPostingAttentionRow(
                              icon: Icons.link_off_rounded,
                              text: '${stale.length} 个模板接管的分期已结束，仍保持停用',
                              actionLabel: '恢复',
                              actionColor: colorScheme.primary,
                              onAction: () => widget.onReleaseStale(stale),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// 提醒区展开后的一行：一句说明 + 一个动作。
class _AutoPostingAttentionRow extends StatelessWidget {
  const _AutoPostingAttentionRow({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.actionColor,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String actionLabel;
  final Color actionColor;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionLabel,
            style: TextStyle(color: actionColor, letterSpacing: 0),
          ),
        ),
      ],
    );
  }
}

/// 列表底部的一行「相关」链接。
///
/// 分期还款计划在「分期」Tab 已经有一份完整列表，这里原来又常驻一份预览
/// （展开态 9 行），同一份数据两处入口，只会慢慢漂移。降级成一行链接后，
/// 模板列表才拿得回首屏。
class _RelatedInstallmentsLink extends StatelessWidget {
  const _RelatedInstallmentsLink({required this.count, this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppListItemPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      backgroundColor: colorScheme.surfaceContainerLowest,
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_rounded,
            size: 17,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count 个分期计划到期自动入账',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '查看',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _AutoPostingTemplateCard extends ConsumerWidget {
  const _AutoPostingTemplateCard({
    required this.template,
    required this.account,
    required this.categoryText,
    required this.onEdit,
    required this.onDelete,
    required this.onRunNow,
    required this.onReleaseTakeOver,
  });

  final MoneyAutoPostingTemplateEntity template;
  final MoneyAccountEntity? account;
  final String categoryText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReleaseTakeOver;
  final VoidCallback onRunNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final runs = ref.watch(currentUserAutoPostingRunsProvider(template.id));
    // 被接管的模板要显示「谁接管了它」：只显示一个「已停用」用户不知道为什么，
    // 更不知道能撤销。
    final takenOverPlanId = template.takenOverByPlanId;
    final takenOverPlanName = takenOverPlanId == null
        ? null
        : ref
              .watch(currentUserInstallmentPlansProvider)
              .maybeWhen(
                data: (items) => items
                    .where((plan) => plan.id == takenOverPlanId)
                    .map((plan) => plan.name)
                    .firstOrNull,
                orElse: () => null,
              );

    return AppSwipeActionTile(
      actions: [
        AppSwipeAction(
          tooltip: '立即执行',
          icon: Icons.play_arrow_rounded,
          foreground: colorScheme.onTertiaryContainer,
          background: colorScheme.tertiaryContainer,
          onPressed: onRunNow,
        ),
        AppSwipeAction(
          tooltip: '编辑',
          icon: Icons.edit_rounded,
          foreground: colorScheme.onPrimaryContainer,
          background: colorScheme.primaryContainer,
          onPressed: onEdit,
        ),
        AppSwipeAction(
          tooltip: '删除',
          icon: Icons.delete_outline_rounded,
          foreground: colorScheme.onErrorContainer,
          background: colorScheme.errorContainer,
          onPressed: onDelete,
        ),
      ],
      child: AppListItemPanel(
        padding: const EdgeInsets.all(12),
        backgroundColor: template.isActive
            ? colorScheme.surfaceContainerLow
            : colorScheme.surfaceContainerLowest,
        child: _AutoPostingTemplateCardContent(
          template: template,
          account: account,
          categoryText: categoryText,
          takenOverPlanName: takenOverPlanName,
          onReleaseTakeOver: onReleaseTakeOver,
          runs: runs.maybeWhen(
            data: (items) => items,
            orElse: () => const <MoneyAutoPostingRunEntity>[],
          ),
        ),
      ),
    );
  }
}

class _AutoPostingTemplateCardContent extends StatelessWidget {
  const _AutoPostingTemplateCardContent({
    required this.template,
    required this.account,
    required this.categoryText,
    required this.onReleaseTakeOver,
    this.takenOverPlanName,
    this.runs = const <MoneyAutoPostingRunEntity>[],
  });

  final MoneyAutoPostingTemplateEntity template;
  final MoneyAccountEntity? account;
  final String categoryText;
  final VoidCallback onReleaseTakeOver;

  /// 接管的分期名称；为 null 表示未被接管（或分期已被删除）。
  final String? takenOverPlanName;
  final List<MoneyAutoPostingRunEntity> runs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final iconColor = template.isActive
        ? template.type == MoneyTransactionType.income
              ? colorScheme.tertiary
              : colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final amountText = maskedMoneyOr(
      formatMoneyMinor(template.amountMinor, template.currencyCode),
      MoneyPrivacy.of(context),
    );
    final subtitle = [
      _scheduleText(template),
      '从 ${_dateText(template.startsOn)} 起',
      if (template.endsOn != null) '至 ${_dateText(template.endsOn!)}',
    ].join(' · ');
    final relationText =
        '${account?.name ?? '账户不可用'} · $categoryText · ${template.paymentMethod.label}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppListItemIcon(
          icon: template.type == MoneyTransactionType.income
              ? Icons.south_west_rounded
              : Icons.north_east_rounded,
          color: iconColor,
          size: 38,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AutoPostingStatusPill(active: template.isActive),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${template.type.label} · $amountText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                relationText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              if (template.notes != null &&
                  template.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  template.notes!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
              if (template.takenOverByPlanId != null) ...[
                const SizedBox(height: 8),
                Divider(height: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.credit_card_rounded,
                      size: 15,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        takenOverPlanName == null
                            ? '已交给分期记账，模板停用'
                            : '已交给分期「$takenOverPlanName」记账，模板停用',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: onReleaseTakeOver,
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '恢复独立入账',
                        style: TextStyle(letterSpacing: 0),
                      ),
                    ),
                  ],
                ),
              ],
              if (runs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Divider(height: 1, color: colorScheme.outlineVariant),
                const SizedBox(height: 6),
                for (final run in runs.take(2)) _AutoPostingRunRow(run: run),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AutoPostingRunRow extends ConsumerWidget {
  const _AutoPostingRunRow({required this.run});

  final MoneyAutoPostingRunEntity run;

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    final toast = FToast()..init(context);
    try {
      await ref
          .read(currentUserMoneyAutoPostingActionsProvider)
          .resetRun(run.id);
      if (!context.mounted) return;
      AppToast.success(toast, context, '已恢复为待执行，可再次执行');
    } catch (error) {
      if (!context.mounted) return;
      AppToast.error(toast, context, '恢复失败，请稍后重试');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (label, icon, color) = switch (run.status) {
      MoneyAutoPostingRunStatus.posted => (
        '已入账',
        Icons.check_circle_outline_rounded,
        colorScheme.primary,
      ),
      MoneyAutoPostingRunStatus.pending => (
        '待执行',
        Icons.schedule_rounded,
        colorScheme.tertiary,
      ),
      MoneyAutoPostingRunStatus.duplicateIgnored => (
        '重复已跳过',
        Icons.help_outline_rounded,
        colorScheme.onSurfaceVariant,
      ),
      MoneyAutoPostingRunStatus.blocked => (
        '已拦截',
        Icons.block_rounded,
        colorScheme.error,
      ),
      MoneyAutoPostingRunStatus.retryableFailed => (
        '执行失败',
        Icons.error_outline_rounded,
        colorScheme.error,
      ),
      MoneyAutoPostingRunStatus.userDeleted => (
        '已删除',
        Icons.delete_outline_rounded,
        colorScheme.onSurfaceVariant,
      ),
    };
    final detail = switch (run.status) {
      MoneyAutoPostingRunStatus.retryableFailed ||
      MoneyAutoPostingRunStatus.blocked => [
        if (run.errorMessage != null && run.errorMessage!.trim().isNotEmpty)
          run.errorMessage!,
      ],
      _ => const <String>[],
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    label,
                    ' ${_runDateTimeText(run.scheduledFor)}'
                        '${run.postedAt == null ? '' : ' · ${_runDateTimeText(run.postedAt!)}'}',
                  ].join(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.error,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),
          if (run.status == MoneyAutoPostingRunStatus.blocked)
            IconButton(
              onPressed: () => _retry(context, ref),
              tooltip: '重新尝试',
              icon: const Icon(Icons.refresh_rounded, size: 16),
              color: colorScheme.error,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}

class _AutoPostingStatusPill extends StatelessWidget {
  const _AutoPostingStatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = active
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final background = active
        ? colorScheme.primaryContainer.withValues(alpha: 0.52)
        : colorScheme.surfaceContainerHighest;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          active ? '启用' : '停用',
          style: theme.textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _AutoPostingFormDialog extends ConsumerStatefulWidget {
  const _AutoPostingFormDialog({this.template});

  final MoneyAutoPostingTemplateEntity? template;

  @override
  ConsumerState<_AutoPostingFormDialog> createState() =>
      _AutoPostingFormDialogState();
}

class _AutoPostingFormDialogState
    extends ConsumerState<_AutoPostingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _merchantController;
  late final TextEditingController _notesController;
  final _customPaymentNameCtrl = TextEditingController();
  late MoneyTransactionType _type;
  late MoneyPaymentMethod _paymentMethod;
  late MoneyAutoPostingFrequency _frequency;
  late int _dayOfMonth;
  late int _weekday;
  late int _timeOfDayMinutes;
  late DateTime _startsOn;
  DateTime? _endsOn;
  late bool _isActive;
  String? _accountId;
  String? _categoryId;
  String? _subCategoryId;
  String? _formError;

  bool get _editing => widget.template != null;

  MoneyCategoryKind get _categoryKind {
    return _type == MoneyTransactionType.income
        ? MoneyCategoryKind.income
        : MoneyCategoryKind.expense;
  }

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _nameController = TextEditingController(text: template?.name ?? '');
    _amountController = TextEditingController(
      text: template == null
          ? ''
          : (template.amountMinor / 100).toStringAsFixed(2),
    );
    _descriptionController = TextEditingController(
      text: template?.description ?? '',
    );
    _merchantController = TextEditingController(text: template?.merchant ?? '');
    _notesController = TextEditingController(text: template?.notes ?? '');
    _customPaymentNameCtrl.text = template?.customPaymentMethodName ?? '';
    _type = template?.type == MoneyTransactionType.income
        ? MoneyTransactionType.income
        : MoneyTransactionType.expense;
    _paymentMethod = template?.paymentMethod ?? MoneyPaymentMethod.cash;
    _frequency = template?.frequency ?? MoneyAutoPostingFrequency.monthly;
    final now = DateTime.now();
    _dayOfMonth = template?.dayOfMonth ?? now.day.clamp(1, 31);
    _weekday = template?.weekday ?? now.weekday;
    _timeOfDayMinutes = template?.timeOfDayMinutes ?? 8 * 60;
    _startsOn = _dateOnly(template?.startsOn ?? now);
    _endsOn = template?.endsOn == null ? null : _dateOnly(template!.endsOn!);
    _isActive = template?.isActive ?? true;
    _accountId = template?.accountId;
    _categoryId = template?.categoryId;
    _subCategoryId = template?.subCategoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    _customPaymentNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentLedger = ref.watch(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const AsyncValue<List<MoneyAccountEntity>>.data(
            <MoneyAccountEntity>[],
          )
        : ref.watch(currentUserMoneyLedgerAccountsProvider(currentLedger.id));
    final catalog = ref.watch(
      currentUserCategoryCatalogProvider(_categoryKind),
    );

    return AppDialogScaffold(
      title: _editing ? '编辑自动记账' : '新增自动记账',
      titleTextAlign: TextAlign.center,
      maxWidth: 560,
      body: Form(
        key: _formKey,
        child: AppFormColumn(
          children: [
            AppTextFormField(
              controller: _nameController,
              labelText: '模板名称',
              prefixIcon: const Icon(Icons.event_repeat_rounded),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入模板名称' : null,
            ),
            FormDropdown<MoneyTransactionType>(
              initialSelection: _type,
              label: '流水类型',
              leadingIcon: const Icon(Icons.swap_vert_rounded),
              width: double.infinity,
              onSelected: (value) {
                if (value == null || value == _type) {
                  return;
                }
                setState(() {
                  _type = value;
                  _accountId = null;
                  _categoryId = null;
                  _subCategoryId = null;
                  _formError = null;
                });
              },
              entries: const [
                DropdownMenuEntry(
                  value: MoneyTransactionType.expense,
                  label: '支出',
                ),
                DropdownMenuEntry(
                  value: MoneyTransactionType.income,
                  label: '收入',
                ),
              ],
            ),
            AppAmountField(
              controller: _amountController,
              labelText: '金额',
              validator: (value) {
                final normalized = value?.trim().replaceAll(',', '') ?? '';
                final amount = double.tryParse(normalized);
                if (amount == null || amount <= 0) {
                  return '请输入有效金额';
                }
                return null;
              },
            ),
            AppTextFormField(
              controller: _descriptionController,
              labelText: '流水描述',
              prefixIcon: const Icon(Icons.subject_rounded),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '请输入流水描述' : null,
            ),
            accounts.when(
              data: (value) {
                final selectableAccounts = _selectableAccountsForType(
                  value.where((account) => account.isActive).toList(),
                  _type,
                );
                return AccountSelector(
                  accounts: selectableAccounts,
                  selectedAccountId: _accountId,
                  emptyText: _type == MoneyTransactionType.income
                      ? '暂无可用于收入的账户'
                      : '暂无可选账户',
                  onChanged: (account) {
                    setState(() {
                      _accountId = account?.id;
                      final methods = _availablePaymentMethodsForAccount(
                        account,
                      );
                      if (!methods.contains(_paymentMethod)) {
                        _paymentMethod = methods.first;
                      }
                      _formError = null;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('账户读取失败'),
            ),
            catalog.when(
              data: (value) => CategorySelector(
                catalog: value,
                selectedCategoryId: _categoryId,
                selectedSubCategoryId: _subCategoryId,
                categoryLabelText: '${_categoryKind.label}分类',
                onChanged: (selection) {
                  setState(() {
                    _categoryId = selection.category?.id;
                    _subCategoryId = selection.subCategory?.id;
                    _formError = null;
                  });
                },
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('分类读取失败'),
            ),
            accounts.when(
              data: (value) {
                final selectedAccount = _accountById(value, _accountId);
                final lockedMethod = _lockedPaymentMethodForAccount(
                  selectedAccount,
                );
                final methods = _availablePaymentMethodsForAccount(
                  selectedAccount,
                );
                final effectivePaymentMethod =
                    _effectivePaymentMethodForAccount(selectedAccount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FormDropdown<MoneyPaymentMethod>(
                      key: ValueKey(
                        'auto-posting-payment-${selectedAccount?.id ?? 'none'}-${effectivePaymentMethod.storageValue}',
                      ),
                      initialSelection: effectivePaymentMethod,
                      label: '支付方式',
                      leadingIcon: const Icon(Icons.credit_card_rounded),
                      width: double.infinity,
                      enabled: lockedMethod == null,
                      enableFilter: true,
                      onSelected: (value) {
                        if (value == null) return;
                        setState(() {
                          _paymentMethod = value;
                        });
                      },
                      entries: methods
                          .map(
                            (method) => DropdownMenuEntry(
                              value: method,
                              label: method.label,
                            ),
                          )
                          .toList(),
                    ),
                    if (effectivePaymentMethod == MoneyPaymentMethod.other)
                      TextFormField(
                        controller: _customPaymentNameCtrl,
                        decoration: const InputDecoration(
                          labelText: '支付方式名称',
                          hintText: '如：美团月付、抖音月付、京东支付',
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const Text('支付方式读取失败'),
            ),
            AppTextFormField(
              controller: _merchantController,
              labelText: '商户',
              prefixIcon: const Icon(Icons.storefront_rounded),
            ),
            FormDropdown<MoneyAutoPostingFrequency>(
              initialSelection: _frequency,
              label: '记账周期',
              leadingIcon: const Icon(Icons.repeat_rounded),
              width: double.infinity,
              onSelected: (value) {
                if (value == null) return;
                setState(() => _frequency = value);
              },
              entries: MoneyAutoPostingFrequency.values
                  .map(
                    (frequency) => DropdownMenuEntry(
                      value: frequency,
                      label: _frequencyLabel(frequency),
                    ),
                  )
                  .toList(),
            ),
            if (_frequency == MoneyAutoPostingFrequency.weekly)
              FormDropdown<int>(
                initialSelection: _weekday,
                label: '每周日期',
                leadingIcon: const Icon(Icons.view_week_rounded),
                width: double.infinity,
                onSelected: (value) {
                  if (value == null) return;
                  setState(() => _weekday = value);
                },
                entries: [
                  for (
                    var day = DateTime.monday;
                    day <= DateTime.sunday;
                    day += 1
                  )
                    DropdownMenuEntry(value: day, label: _weekdayLabel(day)),
                ],
              ),
            if (_frequency == MoneyAutoPostingFrequency.monthly)
              FormDropdown<int>(
                initialSelection: _dayOfMonth,
                label: '每月日期',
                leadingIcon: const Icon(Icons.calendar_view_month_rounded),
                width: double.infinity,
                menuHeight: 320,
                onSelected: (value) {
                  if (value == null) return;
                  setState(() => _dayOfMonth = value);
                },
                entries: [
                  for (var day = 1; day <= 31; day += 1)
                    DropdownMenuEntry(value: day, label: '$day 日'),
                ],
              ),
            _TimePickerField(
              minutes: _timeOfDayMinutes,
              onChanged: (value) {
                setState(() => _timeOfDayMinutes = value);
              },
            ),
            DateTimePicker(
              selectedDate: _startsOn,
              showTime: false,
              label: '开始日期：${_dateText(_startsOn)}',
              onChanged: (value) {
                setState(() {
                  _startsOn = _dateOnly(value);
                  _formError = null;
                });
              },
            ),
            _EndDateField(
              date: _endsOn,
              fallbackDate: _startsOn,
              onChanged: (value) {
                setState(() {
                  _endsOn = value == null ? null : _dateOnly(value);
                  _formError = null;
                });
              },
            ),
            SwitchListTile.adaptive(
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('启用模板'),
              subtitle: const Text('启用后到达指定时间会自动生成已完成流水'),
            ),
            AppTextFormField(
              controller: _notesController,
              labelText: '备注',
              prefixIcon: const Icon(Icons.notes_rounded),
              minLines: 2,
              maxLines: 3,
            ),
            if (_formError != null) AppFormHint(text: _formError!),
          ],
        ),
      ),
      actionsAlignment: WrapAlignment.center,
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        cancelTooltip: '取消',
        confirmTooltip: _editing ? '保存' : '创建',
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_accountId == null) {
      setState(() => _formError = '请选择账户');
      return;
    }
    if (_categoryId == null) {
      setState(() => _formError = '请选择分类');
      return;
    }
    final endsOn = _endsOn;
    if (endsOn != null && _dateOnly(endsOn).isBefore(_dateOnly(_startsOn))) {
      setState(() => _formError = '结束日期不能早于开始日期');
      return;
    }

    final currentLedger = ref.read(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const <MoneyAccountEntity>[]
        : ref
              .read(currentUserMoneyLedgerAccountsProvider(currentLedger.id))
              .maybeWhen(
                data: (value) => value,
                orElse: () => const <MoneyAccountEntity>[],
              );
    final selectedAccount = _accountById(accounts, _accountId);
    final currencyCode =
        selectedAccount?.currencyCode ??
        (widget.template?.currencyCode ?? 'CNY');

    Navigator.of(context).pop(
      _AutoPostingFormResult(
        name: _nameController.text.trim(),
        type: _type,
        amountMinor: parseMoneyAmountToMinor(_amountController.text),
        currencyCode: currencyCode,
        description: _descriptionController.text.trim(),
        notes: _blankToNull(_notesController.text),
        merchant: _blankToNull(_merchantController.text),
        accountId: _accountId!,
        categoryId: _categoryId!,
        subCategoryId: _subCategoryId,
        paymentMethod: _paymentMethod,
        customPaymentMethodName: _customPaymentNameCtrl.text.trim().isEmpty
            ? null
            : _customPaymentNameCtrl.text.trim(),
        frequency: _frequency,
        dayOfMonth: _frequency == MoneyAutoPostingFrequency.monthly
            ? _dayOfMonth
            : null,
        weekday: _frequency == MoneyAutoPostingFrequency.weekly
            ? _weekday
            : null,
        timeOfDayMinutes: _timeOfDayMinutes,
        startsOn: _startsOn,
        endsOn: _endsOn,
        isActive: _isActive,
      ),
    );
  }

  MoneyPaymentMethod _effectivePaymentMethodForAccount(
    MoneyAccountEntity? account,
  ) {
    final lockedMethod = _lockedPaymentMethodForAccount(account);
    if (lockedMethod != null) {
      return lockedMethod;
    }
    final methods = _availablePaymentMethodsForAccount(account);
    if (methods.contains(_paymentMethod)) {
      return _paymentMethod;
    }
    return methods.first;
  }
}

class _TimePickerField extends StatelessWidget {
  const _TimePickerField({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final controls = theme.controlTokens;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _pickTime(context),
        borderRadius: BorderRadius.circular(radius.md),
        child: Container(
          constraints: BoxConstraints(minHeight: controls.compactFieldHeight),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: appFieldFillColor(colorScheme, enabled: true),
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(
              color: appFieldBorderColor(colorScheme, enabled: true),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '记账时间：${_timeText(minutes)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) {
      return;
    }
    onChanged(picked.hour * 60 + picked.minute);
  }
}

class _EndDateField extends StatelessWidget {
  const _EndDateField({
    required this.date,
    required this.fallbackDate,
    required this.onChanged,
  });

  final DateTime? date;
  final DateTime fallbackDate;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DateTimePicker(
            selectedDate: date ?? fallbackDate,
            showTime: false,
            label: date == null ? '结束日期：无结束日期' : '结束日期：${_dateText(date!)}',
            onChanged: (value) => onChanged(value),
          ),
        ),
        const SizedBox(width: 8),
        AppIconActionButton(
          tooltip: '清除结束日期',
          onPressed: date == null ? null : () => onChanged(null),
          icon: Icons.close_rounded,
          variant: AppIconActionVariant.outlined,
        ),
      ],
    );
  }
}

class _AutoPostingFormResult {
  const _AutoPostingFormResult({
    required this.name,
    required this.type,
    required this.amountMinor,
    required this.currencyCode,
    required this.description,
    required this.accountId,
    required this.categoryId,
    required this.paymentMethod,
    this.customPaymentMethodName,
    required this.frequency,
    required this.timeOfDayMinutes,
    required this.startsOn,
    required this.isActive,
    this.notes,
    this.merchant,
    this.subCategoryId,
    this.dayOfMonth,
    this.weekday,
    this.endsOn,
  });

  final String name;
  final MoneyTransactionType type;
  final int amountMinor;
  final String currencyCode;
  final String description;
  final String? notes;
  final String? merchant;
  final String accountId;
  final String categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod paymentMethod;
  final String? customPaymentMethodName;
  final MoneyAutoPostingFrequency frequency;
  final int? dayOfMonth;
  final int? weekday;
  final int timeOfDayMinutes;
  final DateTime startsOn;
  final DateTime? endsOn;
  final bool isActive;

  MoneyAutoPostingTemplateDraft toDraft() {
    return MoneyAutoPostingTemplateDraft(
      name: name,
      type: type,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      description: description,
      notes: notes,
      merchant: merchant,
      accountId: accountId,
      categoryId: categoryId,
      subCategoryId: subCategoryId,
      paymentMethod: paymentMethod,
      customPaymentMethodName: customPaymentMethodName,
      frequency: frequency,
      dayOfMonth: dayOfMonth,
      weekday: weekday,
      timeOfDayMinutes: timeOfDayMinutes,
      startsOn: startsOn,
      endsOn: endsOn,
      isActive: isActive,
    );
  }

  MoneyAutoPostingTemplateUpdate toUpdate(
    MoneyAutoPostingTemplateEntity template,
  ) {
    return MoneyAutoPostingTemplateUpdate(
      id: template.id,
      name: name,
      type: type,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      description: description,
      notes: notes,
      merchant: merchant,
      accountId: accountId,
      categoryId: categoryId,
      subCategoryId: subCategoryId,
      paymentMethod: paymentMethod,
      customPaymentMethodName: customPaymentMethodName,
      ledgerId: template.ledgerId,
      frequency: frequency,
      dayOfMonth: dayOfMonth,
      weekday: weekday,
      timeOfDayMinutes: timeOfDayMinutes,
      startsOn: startsOn,
      endsOn: endsOn,
      isActive: isActive,
    );
  }
}

MoneyAccountEntity? _accountById(
  List<MoneyAccountEntity> accounts,
  String? id,
) {
  if (id == null) {
    return null;
  }
  for (final account in accounts) {
    if (account.id == id) {
      return account;
    }
  }
  return null;
}

List<MoneyAccountEntity> _selectableAccountsForType(
  List<MoneyAccountEntity> accounts,
  MoneyTransactionType type,
) {
  if (type == MoneyTransactionType.income) {
    return accounts
        .where(
          (account) => account.type.isAssetLike && !account.type.isDebtLike,
        )
        .toList();
  }
  return accounts
      .where(
        (account) =>
            account.type.isAssetLike ||
            account.type.isCreditLike ||
            account.type.isInternal,
      )
      .toList();
}

MoneyPaymentMethod? _lockedPaymentMethodForAccount(
  MoneyAccountEntity? account,
) {
  return switch (account?.type) {
    MoneyAccountType.cash => MoneyPaymentMethod.cash,
    MoneyAccountType.huabei => MoneyPaymentMethod.huabei,
    MoneyAccountType.baitiao => MoneyPaymentMethod.baitiao,
    MoneyAccountType.alipay => MoneyPaymentMethod.alipay,
    MoneyAccountType.wechat => MoneyPaymentMethod.wechatPay,
    MoneyAccountType.cloudQuickPass => MoneyPaymentMethod.unionPay,
    _ => null,
  };
}

List<MoneyPaymentMethod> _availablePaymentMethodsForAccount(
  MoneyAccountEntity? account,
) {
  final lockedMethod = _lockedPaymentMethodForAccount(account);
  if (lockedMethod != null) {
    return [lockedMethod];
  }
  return switch (account?.type) {
    MoneyAccountType.creditCard => const [
      MoneyPaymentMethod.creditCard,
      MoneyPaymentMethod.bankTransfer,
      MoneyPaymentMethod.alipay,
      MoneyPaymentMethod.wechatPay,
      MoneyPaymentMethod.unionPay,
      MoneyPaymentMethod.onlinePayment,
      MoneyPaymentMethod.thirdParty,
      MoneyPaymentMethod.other,
    ],
    MoneyAccountType.meituanCredit || MoneyAccountType.otherCredit => const [
      MoneyPaymentMethod.onlinePayment,
      MoneyPaymentMethod.thirdParty,
      MoneyPaymentMethod.alipay,
      MoneyPaymentMethod.wechatPay,
      MoneyPaymentMethod.bankTransfer,
      MoneyPaymentMethod.other,
    ],
    _ => MoneyPaymentMethod.values,
  };
}

String _categoryText(
  MoneyAutoPostingTemplateEntity template,
  MoneyCategoryCatalog expenseCatalog,
  MoneyCategoryCatalog incomeCatalog,
) {
  final catalog = template.type == MoneyTransactionType.income
      ? incomeCatalog
      : expenseCatalog;
  final category = catalog.categoryById(template.categoryId);
  final subCategory = catalog.subCategoryById(template.subCategoryId);
  if (category == null) {
    return '分类不可用';
  }
  if (subCategory == null) {
    return category.name;
  }
  return '${category.name}/${subCategory.name}';
}

String _scheduleText(MoneyAutoPostingTemplateEntity template) {
  final time = _timeText(template.timeOfDayMinutes);
  return switch (template.frequency) {
    MoneyAutoPostingFrequency.daily => '每天 $time',
    MoneyAutoPostingFrequency.weekly =>
      '每周${_weekdayLabel(template.weekday ?? template.startsOn.weekday)} $time',
    MoneyAutoPostingFrequency.monthly =>
      '每月 ${template.dayOfMonth ?? template.startsOn.day} 日 $time',
  };
}

String _frequencyLabel(MoneyAutoPostingFrequency frequency) {
  return switch (frequency) {
    MoneyAutoPostingFrequency.daily => '每天',
    MoneyAutoPostingFrequency.weekly => '每周',
    MoneyAutoPostingFrequency.monthly => '每月',
  };
}

String _weekdayLabel(int weekday) {
  return switch (weekday) {
    DateTime.monday => '周一',
    DateTime.tuesday => '周二',
    DateTime.wednesday => '周三',
    DateTime.thursday => '周四',
    DateTime.friday => '周五',
    DateTime.saturday => '周六',
    DateTime.sunday => '周日',
    _ => '周一',
  };
}

String _dateText(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _timeText(int minutes) {
  final clampedMinutes = minutes.clamp(0, 24 * 60 - 1);
  final hour = (clampedMinutes ~/ 60).toString().padLeft(2, '0');
  final minute = (clampedMinutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _runDateTimeText(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

DateTime _dateOnly(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
