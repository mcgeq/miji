import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_selector.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_selector.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

class MoneyInstallmentsSection extends ConsumerStatefulWidget {
  const MoneyInstallmentsSection({super.key});

  @override
  ConsumerState<MoneyInstallmentsSection> createState() =>
      _MoneyInstallmentsSectionState();
}

class _MoneyInstallmentsSectionState
    extends ConsumerState<MoneyInstallmentsSection> {
  FToast? _toast;

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(currentUserInstallmentPlansProvider);
    final currentLedger = ref.watch(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const AsyncValue<List<MoneyAccountEntity>>.data(
            <MoneyAccountEntity>[],
          )
        : ref.watch(currentUserMoneyLedgerAccountsProvider(currentLedger.id));
    final catalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
    );

    return plans.when(
      data: (value) => accounts.when(
        data: (accountRows) => catalog.when(
          data: (categoryCatalog) => _MoneyInstallmentsContent(
            plans: value,
            accounts: accountRows,
            categoryCatalog: categoryCatalog,
            onCreate: _showCreateDialog,
            onCancel: _cancelPlan,
            onPostDetail: _postDetail,
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => AppErrorState(
            title: '读取分类失败',
            onRetry: () => ref.invalidate(
              currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AppErrorState(
          title: '读取账户失败',
          onRetry: () {
            final ledger = ref.read(currentUserCurrentLedgerValueProvider);
            if (ledger == null) {
              ref.invalidate(currentUserMoneyLedgersProvider);
              return;
            }
            ref.invalidate(currentUserMoneyLedgerAccountsProvider(ledger.id));
          },
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AppErrorState(
        title: '读取分期失败',
        onRetry: () => ref.invalidate(currentUserInstallmentPlansProvider),
      ),
    );
  }

  Future<void> _showCreateDialog(
    List<MoneyAccountEntity> accounts,
    MoneyCategoryCatalog categoryCatalog,
  ) async {
    final result = await showAppResponsiveDialog<MoneyInstallmentPlanDraft>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => InstallmentPlanFormDialog(
        accounts: accounts,
        categoryCatalog: categoryCatalog,
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyInstallmentActionsProvider)
          .createInstallmentPlan(result);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '分期计划已创建');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _cancelPlan(MoneyInstallmentPlanEntity plan) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '取消分期',
      message: '取消后会释放尚未入账的冻结本金，确认继续？',
      confirmLabel: '确认取消',
      destructive: true,
      icon: Icons.close_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyInstallmentActionsProvider)
          .cancelInstallmentPlan(plan.id);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '分期计划已取消');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _postDetail(MoneyInstallmentDetailEntity detail) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '分期入账',
      message: '确认将第 ${detail.periodNumber} 期生成支出流水？',
      confirmLabel: '确认入账',
      icon: Icons.receipt_long_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyInstallmentActionsProvider)
          .postInstallmentDetail(detail.id);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '分期已入账');
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
        MoneyRepositoryErrorCode.invalidInstallmentAmount => '请检查分期金额和期数',
        MoneyRepositoryErrorCode.invalidInstallmentAccount => '请选择信用账户',
        MoneyRepositoryErrorCode.installmentPlanNotFound => '分期计划不可用',
        MoneyRepositoryErrorCode.invalidInstallmentStatus => '当前分期状态不可操作',
        MoneyRepositoryErrorCode.creditCardLimitExceeded => '信用账户占用额度不能超过信用额度',
        MoneyRepositoryErrorCode.ledgerNotFound => '分摊账本不可用',
        MoneyRepositoryErrorCode.memberNotFound => '分摊成员不可用',
        MoneyRepositoryErrorCode.invalidSplitAmount => '请检查分摊金额或比例',
        MoneyRepositoryErrorCode.invalidSplitTransaction => '当前流水不支持分摊',
        MoneyRepositoryErrorCode.accountNotFound => '账户不可用',
        MoneyRepositoryErrorCode.databaseReadFailed => '读取失败',
        MoneyRepositoryErrorCode.databaseWriteFailed => '保存失败',
        _ => '操作失败',
      };
    }
    return '操作失败';
  }
}

class _MoneyInstallmentsContent extends StatelessWidget {
  const _MoneyInstallmentsContent({
    required this.plans,
    required this.accounts,
    required this.categoryCatalog,
    required this.onCreate,
    required this.onCancel,
    required this.onPostDetail,
  });

  final List<MoneyInstallmentPlanEntity> plans;
  final List<MoneyAccountEntity> accounts;
  final MoneyCategoryCatalog categoryCatalog;
  final void Function(List<MoneyAccountEntity>, MoneyCategoryCatalog) onCreate;
  final ValueChanged<MoneyInstallmentPlanEntity> onCancel;
  final ValueChanged<MoneyInstallmentDetailEntity> onPostDetail;

  @override
  Widget build(BuildContext context) {
    final creditAccounts = accounts
        .where((account) => account.isActive && account.type.isCreditLike)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        if (creditAccounts.isEmpty)
          const Expanded(
            child: AppEmptyState(
              title: '还没有可用信用账户',
              message: '请先创建信用卡、花呗、白条等信用账户',
              icon: Icons.credit_card_rounded,
            ),
          )
        else if (categoryCatalog.categories.isEmpty)
          const Expanded(
            child: AppEmptyState(
              title: '还没有支出分类',
              message: '请先初始化或创建支出分类',
              icon: Icons.category_rounded,
            ),
          )
        else if (plans.isEmpty)
          const Expanded(
            child: AppEmptyState(
              title: '还没有分期计划',
              message: '新增分期后会冻结信用账户本金',
              icon: Icons.calendar_month_rounded,
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: plans.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _InstallmentPlanCard(
                  plan: plans[index],
                  account: _accountForPlan(plans[index]),
                  categoryText: _categoryText(plans[index]),
                  onPostDetail: onPostDetail,
                  onCancel: plans[index].isActive
                      ? () => onCancel(plans[index])
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }

  MoneyAccountEntity? _accountForPlan(MoneyInstallmentPlanEntity plan) {
    for (final account in accounts) {
      if (account.id == plan.accountId) {
        return account;
      }
    }
    return null;
  }

  String _categoryText(MoneyInstallmentPlanEntity plan) {
    final category = categoryCatalog.categoryById(plan.categoryId);
    final subCategory = categoryCatalog.subCategoryById(plan.subCategoryId);
    if (category == null) {
      return '分类不可用';
    }
    if (subCategory == null) {
      return category.name;
    }
    return '${category.name} / ${subCategory.name}';
  }
}

class _InstallmentPlanCard extends ConsumerWidget {
  const _InstallmentPlanCard({
    required this.plan,
    required this.account,
    required this.categoryText,
    required this.onPostDetail,
    required this.onCancel,
  });

  final MoneyInstallmentPlanEntity plan;
  final MoneyAccountEntity? account;
  final String categoryText;
  final ValueChanged<MoneyInstallmentDetailEntity> onPostDetail;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final details = ref.watch(currentUserInstallmentDetailsProvider(plan.id));

    return AppSwipeActionTile(
      actions: [
        if (onCancel != null)
          AppSwipeAction(
            tooltip: '取消分期',
            icon: Icons.close_rounded,
            foreground: colorScheme.onErrorContainer,
            background: colorScheme.errorContainer,
            onPressed: onCancel!,
          ),
      ],
      child: AppListItemPanel(
        padding: const EdgeInsets.all(14),
        onTap: () => _showDetails(context),
        child: details.when(
          data: (rows) => _InstallmentPlanSummary(
            plan: plan,
            account: account,
            categoryText: categoryText,
            details: rows,
            onOpenDetails: () => _showDetails(context),
          ),
          loading: () => _InstallmentPlanSummary(
            plan: plan,
            account: account,
            categoryText: categoryText,
            details: null,
            onOpenDetails: () => _showDetails(context),
            loadingDetails: true,
          ),
          error: (error, stackTrace) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InstallmentPlanSummary(
                plan: plan,
                account: account,
                categoryText: categoryText,
                details: null,
                onOpenDetails: () => _showDetails(context),
              ),
              const SizedBox(height: 8),
              Text(
                '读取明细失败',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDetails(BuildContext context) {
    return showAppResponsiveDialog<void>(
      context: context,
      builder: (context) => _InstallmentDetailsDialog(
        plan: plan,
        account: account,
        categoryText: categoryText,
        onPostDetail: onPostDetail,
      ),
    );
  }
}

class _InstallmentPlanSummary extends StatelessWidget {
  const _InstallmentPlanSummary({
    required this.plan,
    required this.account,
    required this.categoryText,
    required this.details,
    required this.onOpenDetails,
    this.loadingDetails = false,
  });

  final MoneyInstallmentPlanEntity plan;
  final MoneyAccountEntity? account;
  final String categoryText;
  final List<MoneyInstallmentDetailEntity>? details;
  final VoidCallback onOpenDetails;
  final bool loadingDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final postedCount = _postedDetailCount(details);
    final pendingCount = details == null
        ? plan.remainingPeriods
        : _pendingDetailCount(details);
    final totalPeriods = plan.totalPeriods;
    final progress = totalPeriods <= 0
        ? 0.0
        : (postedCount / totalPeriods).clamp(0.0, 1.0).toDouble();
    final status = _effectivePlanStatus(plan, details);
    final nextDetail = _nextPendingDetail(details);

    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = AppResponsive.of(
          context,
          width: constraints.maxWidth,
        );
        final compact = responsive.isCompact;
        final metricGap = compact ? 8.0 : 10.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppListItemIcon(
                  icon: Icons.event_repeat_rounded,
                  color: colorScheme.primary,
                  size: compact ? 36 : 40,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _InstallmentStatusPill(status: status),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${account?.name ?? '账户不可用'} · $categoryText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                AppIconActionButton(
                  tooltip: '查看明细',
                  onPressed: onOpenDetails,
                  icon: Icons.format_list_bulleted_rounded,
                  iconSize: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已入账 $postedCount/$totalPeriods 期',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: loadingDetails ? null : progress,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            if (compact)
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _InstallmentSummaryMetric(
                          label: '每期',
                          amountMinor: plan.periodAmountMinor,
                          currencyCode: plan.currencyCode,
                          tone: MoneyAmountTone.expense,
                        ),
                      ),
                      SizedBox(width: metricGap),
                      Expanded(
                        child: _InstallmentSummaryMetric(
                          label: '剩余',
                          text: status == MoneyInstallmentPlanStatus.completed
                              ? '0 期'
                              : '$pendingCount 期',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: metricGap),
                  Row(
                    children: [
                      Expanded(
                        child: _InstallmentSummaryMetric(
                          label: '下一期',
                          text: nextDetail == null
                              ? status.label
                              : _dateText(nextDetail.dueDate),
                        ),
                      ),
                      SizedBox(width: metricGap),
                      Expanded(
                        child: _InstallmentSummaryMetric(
                          label: '总应还',
                          amountMinor: plan.totalPayableMinor,
                          currencyCode: plan.currencyCode,
                          tone: MoneyAmountTone.expense,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Wrap(
                spacing: metricGap,
                runSpacing: metricGap,
                children: [
                  _InstallmentSummaryMetric(
                    label: '总应还',
                    amountMinor: plan.totalPayableMinor,
                    currencyCode: plan.currencyCode,
                    tone: MoneyAmountTone.expense,
                    width: 132,
                  ),
                  _InstallmentSummaryMetric(
                    label: '本金',
                    amountMinor: plan.totalPrincipalMinor,
                    currencyCode: plan.currencyCode,
                    tone: MoneyAmountTone.credit,
                    width: 132,
                  ),
                  _InstallmentSummaryMetric(
                    label: '利息',
                    amountMinor: plan.totalInterestMinor,
                    currencyCode: plan.currencyCode,
                    tone: MoneyAmountTone.warning,
                    width: 132,
                  ),
                  _InstallmentSummaryMetric(
                    label: '下一期',
                    text: nextDetail == null
                        ? status.label
                        : _dateText(nextDetail.dueDate),
                    width: 132,
                  ),
                  _InstallmentSummaryMetric(
                    label: '剩余',
                    text: status == MoneyInstallmentPlanStatus.completed
                        ? '0 期'
                        : '$pendingCount 期',
                    width: 96,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _InstallmentSummaryMetric extends StatelessWidget {
  const _InstallmentSummaryMetric({
    required this.label,
    this.amountMinor,
    this.currencyCode = 'CNY',
    this.tone = MoneyAmountTone.neutral,
    this.text,
    this.width,
  }) : assert(amountMinor != null || text != null);

  final String label;
  final int? amountMinor;
  final String currencyCode;
  final MoneyAmountTone tone;
  final String? text;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.36),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              if (amountMinor == null)
                Text(
                  text!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                )
              else
                MoneyAmountText(
                  amountMinor: amountMinor!,
                  currencyCode: currencyCode,
                  tone: tone,
                  textStyle: theme.textTheme.titleSmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstallmentStatusPill extends StatelessWidget {
  const _InstallmentStatusPill({required this.status});

  final MoneyInstallmentPlanStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (foreground, background) = switch (status) {
      MoneyInstallmentPlanStatus.active => (
        colorScheme.primary,
        colorScheme.primaryContainer.withValues(alpha: 0.52),
      ),
      MoneyInstallmentPlanStatus.completed => (
        colorScheme.tertiary,
        colorScheme.tertiaryContainer.withValues(alpha: 0.52),
      ),
      MoneyInstallmentPlanStatus.cancelled => (
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHighest,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          status.label,
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

class _InstallmentDetailsDialog extends ConsumerWidget {
  const _InstallmentDetailsDialog({
    required this.plan,
    required this.account,
    required this.categoryText,
    required this.onPostDetail,
  });

  final MoneyInstallmentPlanEntity plan;
  final MoneyAccountEntity? account;
  final String categoryText;
  final ValueChanged<MoneyInstallmentDetailEntity> onPostDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(currentUserInstallmentDetailsProvider(plan.id));

    return AppDialogScaffold(
      title: plan.name,
      subtitle: '${account?.name ?? '账户不可用'} · $categoryText',
      maxWidth: 560,
      body: details.when(
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(
              title: '还没有分期明细',
              message: '创建分期后会在这里展示每期入账安排',
              icon: Icons.format_list_bulleted_rounded,
            );
          }
          return Column(
            children: [
              for (var index = 0; index < rows.length; index++) ...[
                if (index > 0) const SizedBox(height: 8),
                _InstallmentDetailRow(
                  detail: rows[index],
                  currencyCode: plan.currencyCode,
                  onPost:
                      _effectivePlanStatus(plan, rows) ==
                              MoneyInstallmentPlanStatus.active &&
                          rows[index].status ==
                              MoneyInstallmentDetailStatus.pending
                      ? () => onPostDetail(rows[index])
                      : null,
                ),
              ],
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => const AppEmptyState(
          title: '读取明细失败',
          message: '稍后重试或返回分期列表刷新',
          icon: Icons.error_outline_rounded,
        ),
      ),
      actions: [
        AppIconActionButton(
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icons.close_rounded,
          variant: AppIconActionVariant.outlined,
        ),
      ],
    );
  }
}

class _InstallmentDetailRow extends StatelessWidget {
  const _InstallmentDetailRow({
    required this.detail,
    required this.currencyCode,
    required this.onPost,
  });

  final MoneyInstallmentDetailEntity detail;
  final String currencyCode;
  final VoidCallback? onPost;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pending = detail.status == MoneyInstallmentDetailStatus.pending;
    final statusColor = pending
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.54),
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 34,
                child: Center(
                  child: Text(
                    detail.periodNumber.toString(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '第 ${detail.periodNumber} 期',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        detail.status.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dateText(detail.dueDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 14,
                    runSpacing: 5,
                    children: [
                      _InstallmentInlineAmount(
                        label: '应还',
                        amountMinor: detail.amountMinor,
                        currencyCode: currencyCode,
                        tone: MoneyAmountTone.expense,
                      ),
                      _InstallmentInlineAmount(
                        label: '本金',
                        amountMinor: detail.principalMinor,
                        currencyCode: currencyCode,
                        tone: MoneyAmountTone.credit,
                      ),
                      _InstallmentInlineAmount(
                        label: '利息',
                        amountMinor: detail.interestMinor,
                        currencyCode: currencyCode,
                        tone: MoneyAmountTone.warning,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onPost != null) ...[
              const SizedBox(width: 6),
              AppIconActionButton(
                tooltip: '入账',
                onPressed: onPost,
                icon: Icons.receipt_long_rounded,
                iconSize: 18,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

int _postedDetailCount(List<MoneyInstallmentDetailEntity>? details) {
  if (details == null) {
    return 0;
  }
  return details
      .where((detail) => detail.status == MoneyInstallmentDetailStatus.posted)
      .length;
}

int _pendingDetailCount(List<MoneyInstallmentDetailEntity>? details) {
  if (details == null) {
    return 0;
  }
  return details
      .where((detail) => detail.status == MoneyInstallmentDetailStatus.pending)
      .length;
}

MoneyInstallmentDetailEntity? _nextPendingDetail(
  List<MoneyInstallmentDetailEntity>? details,
) {
  if (details == null) {
    return null;
  }
  final pending =
      details
          .where(
            (detail) => detail.status == MoneyInstallmentDetailStatus.pending,
          )
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return pending.isEmpty ? null : pending.first;
}

MoneyInstallmentPlanStatus _effectivePlanStatus(
  MoneyInstallmentPlanEntity plan,
  List<MoneyInstallmentDetailEntity>? details,
) {
  if (plan.status == MoneyInstallmentPlanStatus.cancelled) {
    return MoneyInstallmentPlanStatus.cancelled;
  }
  if (details == null || details.isEmpty) {
    return plan.status;
  }
  final allPosted = details.every(
    (detail) => detail.status == MoneyInstallmentDetailStatus.posted,
  );
  return allPosted ? MoneyInstallmentPlanStatus.completed : plan.status;
}

class _InstallmentInlineAmount extends StatelessWidget {
  const _InstallmentInlineAmount({
    required this.label,
    required this.amountMinor,
    required this.currencyCode,
    required this.tone,
  });

  final String label;
  final int amountMinor;
  final String currencyCode;
  final MoneyAmountTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        MoneyAmountText(
          amountMinor: amountMinor,
          currencyCode: currencyCode,
          tone: tone,
          textStyle: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class InstallmentPlanFormDialog extends StatefulWidget {
  const InstallmentPlanFormDialog({
    super.key,
    required this.accounts,
    required this.categoryCatalog,
  });

  final List<MoneyAccountEntity> accounts;
  final MoneyCategoryCatalog categoryCatalog;

  @override
  State<InstallmentPlanFormDialog> createState() =>
      _InstallmentPlanFormDialogState();
}

class _InstallmentPlanFormDialogState extends State<InstallmentPlanFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController(text: '0');
  final _periodsController = TextEditingController(text: '12');
  final _notesController = TextEditingController();
  MoneyAccountEntity? _account;
  String? _categoryId;
  String? _subCategoryId;
  String? _categoryErrorText;
  DateTime _firstDueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    _account = widget.accounts.isEmpty ? null : widget.accounts.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _principalController.dispose();
    _interestController.dispose();
    _periodsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountCurrencyCode = _account?.currencyCode ?? 'CNY';

    return AppDialogScaffold(
      title: '新增分期',
      maxWidth: 460,
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
              prefixIcon: const Icon(Icons.edit_calendar_rounded),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return '请输入名称';
                if (text.length > 40) return '名称最多40个字符';
                return null;
              },
            ),
            AccountSelector(
              accounts: widget.accounts,
              selectedAccountId: _account?.id,
              onChanged: (account) => setState(() => _account = account),
              labelText: '信用账户',
              emptyText: '暂无信用账户',
            ),
            CategorySelector(
              catalog: widget.categoryCatalog,
              selectedCategoryId: _categoryId,
              selectedSubCategoryId: _subCategoryId,
              categoryLabelText: '支出分类',
              onChanged: (selection) {
                setState(() {
                  _categoryId = selection.category?.id;
                  _subCategoryId = selection.subCategory?.id;
                  _categoryErrorText = null;
                });
              },
            ),
            if (_categoryErrorText != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _categoryErrorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            AppAmountField(
              controller: _principalController,
              labelText: '本金',
              currencyCode: accountCurrencyCode,
              validator: _validatePositiveAmount,
            ),
            AppAmountField(
              controller: _interestController,
              labelText: '总利息',
              currencyCode: accountCurrencyCode,
              validator: _validateNonNegativeAmount,
            ),
            AppTextFormField(
              controller: _periodsController,
              keyboardType: TextInputType.number,
              labelText: '期数',
              prefixIcon: const Icon(Icons.format_list_numbered_rounded),
              validator: (value) {
                final periods = int.tryParse(value?.trim() ?? '');
                if (periods == null || periods <= 0) return '请输入有效期数';
                if (periods > 120) return '期数不能超过120';
                return null;
              },
            ),
            DateTimePicker(
              selectedDate: _firstDueDate,
              showTime: false,
              label: '首期入账日 ${_dateText(_firstDueDate)}',
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
              onChanged: (value) => setState(() => _firstDueDate = value),
            ),
            AppTextFormField(
              controller: _notesController,
              minLines: 2,
              maxLines: 3,
              labelText: '备注',
              prefixIcon: const Icon(Icons.notes_rounded),
            ),
          ],
        ),
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: '创建',
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final account = _account;
    if (account == null) {
      return;
    }
    final categoryId = _categoryId;
    if (categoryId == null) {
      setState(() => _categoryErrorText = '请选择支出分类');
      return;
    }

    Navigator.of(context).pop(
      MoneyInstallmentPlanDraft(
        accountId: account.id,
        name: _nameController.text.trim(),
        categoryId: categoryId,
        subCategoryId: _subCategoryId,
        totalPrincipalMinor: parseMoneyAmountToMinor(_principalController.text),
        totalInterestMinor: parseMoneyAmountToMinor(_interestController.text),
        totalPeriods: int.parse(_periodsController.text.trim()),
        firstDueDate: _firstDueDate,
        currencyCode: account.currencyCode,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  String? _validatePositiveAmount(String? value) {
    try {
      if (parseMoneyAmountToMinor(value ?? '') <= 0) {
        return '金额必须大于0';
      }
      return null;
    } catch (_) {
      return '请输入有效金额';
    }
  }

  String? _validateNonNegativeAmount(String? value) {
    try {
      if (parseMoneyAmountToMinor(value ?? '') < 0) {
        return '金额不能小于0';
      }
      return null;
    } catch (_) {
      return '请输入有效金额';
    }
  }
}

String _dateText(DateTime date) {
  final local = date.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
