import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_filter_strip.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';
import 'package:miji/core/presentation/components/paged_load_more_list.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/account_card_info.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_icon_catalog.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_presentation_helpers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_progress_bar.dart';
import 'package:miji/features/bookkeeping/presentation/categories/category_icon.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';
import 'package:miji/features/bookkeeping/providers/account_flow_providers.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

/// 打开账户弹窗。
///
/// 点整张卡和点「查看流水」打开的是**同一个**弹窗（同一份数据），区别只在
/// 入口显不显式 —— 不维护第二条路径，也就不会出现「按钮里看到的数和卡面
/// 不一致」。
///
/// 弹窗里**不做金额遮罩**：它是用户主动点进来的详情页，卡面已经遮过一次，
/// 这里再遮既没有隐私收益，又会被当成「坏了」—— 弹窗里没有眼睛图标，
/// 遮住之后用户没有第二个开关可以打开它（曾经就是「点开还是 ••••，也点不动」）。
Future<void> showAccountDetailSheet({
  required BuildContext context,
  required MoneyAccountEntity account,
  VoidCallback? onOpenFullTransactions,
}) {
  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: true,
    builder: (sheetContext) => AccountDetailSheet(
      account: account,
      onOpenFullTransactions: onOpenFullTransactions,
    ),
  );
}

/// 流水时间范围。授信账户的「本期」直接用账单区间，与账单对账口径一致。
enum AccountFlowRange {
  current('本月'),
  recent90('近 90 天'),
  all('全部');

  const AccountFlowRange(this.label);

  final String label;
}

/// 时间范围 → 查询区间。
///
/// 返回值会进 [AccountFlowRequest]，而它是 `FutureProvider.family` 的 key，
/// 所以**必须归一到「天」**：`DateTime.now()` 带毫秒，每帧都不一样，key 就
/// 每帧变一次 —— provider 被销毁重建，列表永远停在 loading。
/// 「近 90 天」曾经就是这么一直转圈的；「本月」因为对齐到月初恰好稳定，
/// 掩盖了这个问题。
(DateTime?, DateTime?) accountFlowRangeBounds({
  required AccountFlowRange range,
  required DateTime now,
  MoneyCreditCardStatement? statement,
}) {
  DateTime dayOf(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  final today = dayOf(now);
  switch (range) {
    case AccountFlowRange.all:
      return (null, null);
    case AccountFlowRange.recent90:
      return (today.subtract(const Duration(days: 90)), null);
    case AccountFlowRange.current:
      // 授信账户有账单区间时，「本期」以账单为准（和账单对账同一个口径）；
      // 没有账单（未设账单日）就退回自然月。
      if (statement != null) {
        return (
          dayOf(statement.periodStart),
          dayOf(statement.periodEndInclusive),
        );
      }
      return (DateTime(today.year, today.month), null);
  }
}

class AccountDetailSheet extends ConsumerStatefulWidget {
  const AccountDetailSheet({
    super.key,
    required this.account,
    this.onOpenFullTransactions,
  });

  final MoneyAccountEntity account;

  /// 「在流水中查看全部」：批量改分类、跨账户搜索仍然只有老面板能做。
  final VoidCallback? onOpenFullTransactions;

  @override
  ConsumerState<AccountDetailSheet> createState() => _AccountDetailSheetState();
}

class _AccountDetailSheetState extends ConsumerState<AccountDetailSheet> {
  AccountFlowRange _range = AccountFlowRange.current;
  MoneyTransactionType? _type;
  int _limit = AccountFlowRequest.pageSize;

  /// 上一次成功拿到的页。
  ///
  /// 「加载更多」会把 `limit` 变大 = 换了一个 provider key，新实例的第一帧
  /// 是 loading；直接渲染 loading 会让列表闪空一下。这里用旧页兜住这一帧。
  MoneyTransactionPage? _lastPage;

  /// 当前渲染用的账户。
  ///
  /// 打开弹窗拿到的是**快照**；用户在弹窗里记一笔之后余额会变，
  /// 继续抱着快照就会出现「列表多了一行、余额没动」。这里在 build 时
  /// 用账户流里最新的一份覆盖（找不到就退回快照）。
  late MoneyAccountEntity _account = widget.account;

  void _refreshAccount() {
    final live = ref
        .watch(currentUserVisibleAccountsProvider)
        .maybeWhen(data: (items) => items, orElse: () => null);
    if (live == null) {
      return;
    }
    for (final item in live) {
      if (item.id == widget.account.id) {
        _account = item;
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _refreshAccount();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = accountCardSemanticOf(_account);
    final creditStatement = _creditStatement();
    final bounds = accountFlowRangeBounds(
      range: _range,
      now: DateTime.now(),
      statement: creditStatement,
    );
    final request = AccountFlowRequest(
      accountId: _account.id,
      type: _type,
      dateStart: bounds.$1,
      dateEnd: bounds.$2,
      limit: _limit,
    );

    final pageAsync = ref.watch(accountFlowPageProvider(request));
    final resolved = pageAsync.value;
    if (resolved != null) {
      _lastPage = resolved;
    }
    final page = resolved ?? _lastPage;

    // 分类目录在 build 里取一次，行渲染只做查表。
    // 不能在 ListView 的 itemBuilder 里 `ref.watch`：列表项是懒构建的，
    // 那一帧未必处于本 widget 的 build 阶段。
    final expenseCatalog = ref
        .watch(currentUserCategoryCatalogProvider(MoneyCategoryKind.expense))
        .maybeWhen(
          data: (catalog) => catalog,
          orElse: () => const MoneyCategoryCatalog.empty(),
        );
    final incomeCatalog = ref
        .watch(currentUserCategoryCatalogProvider(MoneyCategoryKind.income))
        .maybeWhen(
          data: (catalog) => catalog,
          orElse: () => const MoneyCategoryCatalog.empty(),
        );

    // 弹窗尺寸：compact 下外层已经给了屏高与整屏宽，这里再封一次顶只是为了让
    // 宽屏（Dialog）也有上界 —— 否则 Column + Expanded 会在无界高度里崩，
    // 而 Dialog 会把内容拉到整屏宽。
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    // 窄屏（bottom sheet）必须整屏宽；只有宽屏的 Dialog 才收窄。
    final maxWidth = AppResponsive.of(context).isCompact
        ? double.infinity
        : 560.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(
              account: _account,
              onClose: () => Navigator.of(context).maybePop(),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            _overview(context, semantic, creditStatement),
            _filters(context),
            Divider(height: 1, color: colorScheme.outlineVariant),
            Expanded(
              child: _list(
                context,
                pageAsync,
                page,
                expenseCatalog,
                incomeCatalog,
              ),
            ),
            _footer(context),
          ],
        ),
      ),
    );
  }

  // ── 概览 ──────────────────────────────────────────────────────────────

  MoneyCreditCardStatement? _creditStatement() {
    if (!_account.type.isCreditLike) {
      return null;
    }
    return ref
        .watch(currentUserCreditCardBillViewProvider(_account.id))
        .maybeWhen(data: (value) => value?.toStatement(), orElse: () => null);
  }

  Widget _overview(
    BuildContext context,
    AccountCardSemantic semantic,
    MoneyCreditCardStatement? statement,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthly = ref
        .watch(currentUserAccountMonthlySummariesProvider)
        .maybeWhen(data: (value) => value[_account.id], orElse: () => null);
    final primary = accountCardPrimaryAmountMinor(_account);
    final secondary = colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      semantic.primaryLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: secondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    MoneyAmountText(
                      amountMinor: primary,
                      currencyCode: _account.currencyCode,
                      tone: _primaryTone(semantic, primary),
                      textStyle: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _sideValue(context, semantic, statement, monthly),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _overviewCaption(context, semantic, statement, monthly),
            maxLines: 2,
            style: theme.textTheme.labelSmall?.copyWith(
              color: secondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.35,
            ),
          ),
          if (semantic.hasProgressBar) ...[
            const SizedBox(height: 8),
            AccountProgressBar(
              value: _progressRatio(semantic),
              color: _progressColor(context, semantic),
            ),
          ],
          // 「初始余额」从卡面搬到这里：它是建账时的输入值，不是当前状态，
          // 只在余额校正 / 对账时才需要，占卡面视觉资源是浪费。
          if (_showsInitialBalance(semantic)) ...[
            const SizedBox(height: 4),
            Text(
              '初始余额（建账时录入） '
              '${formatMoneyMinor(_account.initialBalanceMinor, _account.currencyCode)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: secondary.withValues(alpha: 0.86),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 授信卡的 `initialBalanceMinor` 是「默认额度」的兜底值，不是期初余额；
  /// 负债卡的期初本金已经写在概览文案里。两者都不再重复。
  bool _showsInitialBalance(AccountCardSemantic semantic) {
    return semantic == AccountCardSemantic.spendable ||
        semantic == AccountCardSemantic.prepaid ||
        semantic == AccountCardSemantic.holding;
  }

  MoneyAmountTone _primaryTone(AccountCardSemantic semantic, int primary) {
    if (semantic == AccountCardSemantic.credit) {
      return MoneyAmountTone.credit;
    }
    // 资产类余额为负（透支）时不该再是中性色。
    if (semantic != AccountCardSemantic.debt && primary < 0) {
      return MoneyAmountTone.expense;
    }
    return MoneyAmountTone.neutral;
  }

  Widget _sideValue(
    BuildContext context,
    AccountCardSemantic semantic,
    MoneyCreditCardStatement? statement,
    MoneyAccountMonthlySummary? monthly,
  ) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    switch (semantic) {
      case AccountCardSemantic.credit:
        final due =
            statement?.amountDueMinor ?? _account.effectivePostedDebtMinor;
        return _SideBlock(
          label: '本期应还',
          value: MoneyAmountText(
            amountMinor: due,
            currencyCode: _account.currencyCode,
            color: _statementColor(context, statement),
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          hint: _statementHint(statement),
          hintColor: _statementColor(context, statement),
        );
      case AccountCardSemantic.debt:
        final progress = accountDebtProgressOf(_account);
        return _SideBlock(
          label: '已还进度',
          value: Text(
            '${(progress.ratio * 100).round()}%',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.moneyColors.expense,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        );
      case AccountCardSemantic.prepaid:
        return _SideBlock(
          label: '本月支出',
          value: MoneyAmountText(
            amountMinor: monthly?.currentExpenseMinor ?? 0,
            currencyCode: _account.currencyCode,
            tone: MoneyAmountTone.expense,
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        );
      case AccountCardSemantic.spendable:
      case AccountCardSemantic.holding:
        final net = monthly?.currentNetMinor ?? 0;
        return _SideBlock(
          label: '本月净',
          value: MoneyAmountText(
            amountMinor: net,
            currencyCode: _account.currencyCode,
            tone: net == 0
                ? MoneyAmountTone.neutral
                : (net > 0 ? MoneyAmountTone.income : MoneyAmountTone.expense),
            showSign: true,
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
              color: net == 0 ? secondary : null,
            ),
          ),
          hint: monthly == null || !monthly.hasCurrentActivity
              ? '本月暂无收支'
              : null,
        );
    }
  }

  String _overviewCaption(
    BuildContext context,
    AccountCardSemantic semantic,
    MoneyCreditCardStatement? statement,
    MoneyAccountMonthlySummary? monthly,
  ) {
    String money(int minor) => formatMoneyMinor(minor, _account.currencyCode);

    switch (semantic) {
      case AccountCardSemantic.credit:
        final usage = accountCreditUsageOf(_account);
        if (!usage.hasLimit) {
          return '未设额度';
        }
        return '已用 ${money(usage.usedMinor)} / ${money(usage.limitMinor)}'
            ' · ${(usage.rawRatio * 100).round()}%';
      case AccountCardSemantic.debt:
        final progress = accountDebtProgressOf(_account);
        if (!progress.hasProgress) {
          return '未录入建账本金，无法计算已还比例';
        }
        return '已还 ${money(progress.repaidMinor)} / 本金 '
            '${money(progress.principalMinor)}（建账时录入）';
      case AccountCardSemantic.prepaid:
        return '本月已用 ${money(monthly?.currentExpenseMinor ?? 0)} · 不含转账';
      case AccountCardSemantic.spendable:
      case AccountCardSemantic.holding:
        // 这里刻意写「不含转账」：卡面/概览的月度合计排除了转账，
        // 而下面的流水列表在按账户筛选时**包含**转账的两条记录。
        return '本月 收 ${money(monthly?.currentIncomeMinor ?? 0)}'
            ' · 支 ${money(monthly?.currentExpenseMinor ?? 0)} · 不含转账';
    }
  }

  double _progressRatio(AccountCardSemantic semantic) {
    return switch (semantic) {
      AccountCardSemantic.credit => accountCreditUsageOf(_account).ratio,
      AccountCardSemantic.debt => accountDebtProgressOf(_account).ratio,
      _ => 0,
    };
  }

  Color _progressColor(BuildContext context, AccountCardSemantic semantic) {
    final theme = Theme.of(context);
    if (semantic == AccountCardSemantic.debt) {
      return theme.moneyColors.expense;
    }
    return switch (accountCreditUsageOf(_account).level) {
      AccountCreditUsageLevel.critical => theme.colorScheme.error,
      AccountCreditUsageLevel.warning => theme.moneyColors.warning,
      AccountCreditUsageLevel.normal => theme.moneyColors.credit,
    };
  }

  Color _statementColor(
    BuildContext context,
    MoneyCreditCardStatement? statement,
  ) {
    final theme = Theme.of(context);
    return switch (statement?.state) {
      MoneyCreditCardStatementState.overdue => theme.colorScheme.error,
      MoneyCreditCardStatementState.dueSoon => theme.moneyColors.warning,
      _ => theme.colorScheme.onSurface,
    };
  }

  String? _statementHint(MoneyCreditCardStatement? statement) {
    if (statement == null) {
      return null;
    }
    final days = DateUtils.dateOnly(
      statement.repaymentDate,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    if (statement.state == MoneyCreditCardStatementState.overdue) {
      return '已逾期 ${statement.repaymentDate.month}月'
          '${statement.repaymentDate.day}日应还';
    }
    if (statement.state == MoneyCreditCardStatementState.settled) {
      return '本期已还清';
    }
    if (days < 0) {
      return '${statement.repaymentDate.month}月'
          '${statement.repaymentDate.day}日还款';
    }
    if (days == 0) {
      return '今天还款';
    }
    return '${statement.repaymentDate.month}月'
        '${statement.repaymentDate.day}日还款 · 还剩 $days 天';
  }

  // ── 筛选 ──────────────────────────────────────────────────────────────

  Widget _filters(BuildContext context) {
    final isCredit = _account.type.isCreditLike;
    return AppFilterStrip(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      children: [
        for (final range in AccountFlowRange.values)
          _SheetChip(
            // 授信账户的「本期」直接取账单区间，和账单对账同口径。
            label: isCredit && range == AccountFlowRange.current
                ? '本期'
                : range.label,
            selected: _range == range,
            onTap: () => _applyFilter(() => _range = range),
          ),
        for (final type in const [
          MoneyTransactionType.expense,
          MoneyTransactionType.income,
          MoneyTransactionType.transfer,
        ])
          _SheetChip(
            label: type.label,
            selected: _type == type,
            // 再点一次取消：只有 6 个 chip，再塞一个「全部类型」会挤爆一行。
            onTap: () =>
                _applyFilter(() => _type = _type == type ? null : type),
          ),
      ],
    );
  }

  /// 任何筛选变化都回到第一页，并丢掉旧页 —— 否则会有一两帧显示上一次筛选的结果。
  void _applyFilter(VoidCallback change) {
    setState(() {
      change();
      _limit = AccountFlowRequest.pageSize;
      _lastPage = null;
    });
  }

  // ── 列表 ──────────────────────────────────────────────────────────────

  Widget _list(
    BuildContext context,
    AsyncValue<MoneyTransactionPage> pageAsync,
    MoneyTransactionPage? page,
    MoneyCategoryCatalog expenseCatalog,
    MoneyCategoryCatalog incomeCatalog,
  ) {
    final theme = Theme.of(context);
    if (page == null) {
      if (pageAsync.hasError) {
        return Center(
          child: Text(
            '读取流水失败',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    if (page.items.isEmpty) {
      return _EmptyFlow(
        hasFilter: _type != null || _range != AccountFlowRange.all,
        onReset: () => _applyFilter(() {
          _range = AccountFlowRange.all;
          _type = null;
        }),
      );
    }

    final rows = _buildRows(page.items);
    final categories = _CategoryIndex(
      expense: expenseCatalog,
      income: incomeCatalog,
    );

    return PagedLoadMoreList<_FlowRow>(
      items: rows,
      hasMore: page.hasMore,
      padding: const EdgeInsets.only(bottom: 8),
      separatorBuilder: (context, index) => const SizedBox.shrink(),
      onLoadMore: () async {
        setState(() => _limit += AccountFlowRequest.pageSize);
      },
      itemBuilder: (context, row, index) {
        return switch (row) {
          _DayHeaderRow() => _DayHeader(day: row.day),
          _TransactionRow() => _FlowTransactionRow(
            transaction: row.transaction,
            category: categories.of(row.transaction),
            onTap: () => showTransactionDetailProviderDialog(
              context: context,
              transaction: row.transaction,
              // 弹窗整条链路都不遮：从「概览 → 流水 → 详情」如果只有最里层
              // 变回 ••••，用户会以为数据丢了，而且这一层同样没有可供切换的
              // 开关。卡面（弹窗外面）该遮还是照遮。
              isAmountHidden: false,
            ),
          ),
        };
      },
    );
  }

  List<_FlowRow> _buildRows(List<MoneyTransactionEntity> items) {
    final rows = <_FlowRow>[];
    DateTime? lastDay;
    for (final transaction in items) {
      final day = DateUtils.dateOnly(transaction.transactionAt.toLocal());
      if (lastDay == null || !DateUtils.isSameDay(lastDay, day)) {
        rows.add(_DayHeaderRow(day));
        lastDay = day;
      }
      rows.add(_TransactionRow(transaction));
    }
    return rows;
  }

  // ── 底部动作 ──────────────────────────────────────────────────────────

  Widget _footer(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.32),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 6, 12, 6 + (bottomInset > 0 ? 4 : 0)),
        child: Row(
          children: [
            // 底部两个动作都只留图标：它们是「对象级入口」，不是这一屏的主任务，
            // 文字按钮会把 320dp 挤到换行，也让概览和筛选显得更矮一等。
            // 名称由 tooltip + 语义标签承担（与卡底「查看流水」同一口径）。
            if (widget.onOpenFullTransactions != null)
              AppIconActionButton(
                tooltip: '在流水中查看全部',
                icon: Icons.list_alt_rounded,
                iconSize: 20,
                onPressed: () {
                  Navigator.of(context).maybePop();
                  widget.onOpenFullTransactions!();
                },
              ),
            const Spacer(),
            AppIconActionButton(
              tooltip: '记一笔',
              icon: Icons.add_rounded,
              iconSize: 20,
              // 弹窗里唯一的写操作，用填充态把它和左边的次要入口分开。
              variant: AppIconActionVariant.filled,
              onPressed: _openCreateTransaction,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateTransaction() async {
    final ledger = ref.read(currentUserEffectiveTransactionLedgerValueProvider);
    await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (formContext) => TransactionFormDialog(
        type: MoneyTransactionType.expense,
        ledger: ledger,
        initialAccountId: _account.id,
        onSubmit: (result) async {
          if (result is! TransactionCreateFormResult) {
            return null;
          }
          try {
            final actions = ref.read(
              currentUserMoneyTransactionActionsProvider,
            );
            final splitConfig = result.splitConfig;
            if (splitConfig == null) {
              await actions.createTransaction(result.draft);
            } else {
              await actions.createTransactionWithSplit(
                result.draft,
                splitConfig,
              );
            }
            return null;
          } catch (_) {
            return '记录失败，请稍后重试';
          }
        },
      ),
    );
  }
}

/// 弹窗头：图标 + 名称 + 类型/币种/账单日 + 关闭。
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.account, required this.onClose});

  final MoneyAccountEntity account;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = account.color == null
        ? appColorFromHex(defaultAccountColorForType(account.type))
        : appColorFromHex(account.color);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(theme.radiusTokens.md),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: AccountIconView(
              account: account,
              size: 20,
              imageSize: 32,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _metaText(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          AppIconActionButton(
            tooltip: '关闭',
            onPressed: onClose,
            icon: Icons.close_rounded,
          ),
        ],
      ),
    );
  }

  String _metaText() {
    final parts = <String>[account.type.label, account.currencyCode];
    if (account.type.isCreditLike) {
      if (account.statementDay != null) {
        parts.add('账单日 ${account.statementDay} 日');
      }
      if (account.repaymentDay != null) {
        parts.add('还款日 ${account.repaymentDay} 日');
      }
    }
    final description = account.description?.trim();
    if (description != null && description.isNotEmpty) {
      parts.add(description);
    }
    return parts.join(' · ');
  }
}

/// 右侧辅助值：标签 + 主值 + 可选提示。
class _SideBlock extends StatelessWidget {
  const _SideBlock({
    required this.label,
    required this.value,
    this.hint,
    this.hintColor,
  });

  final String label;
  final Widget value;
  final String? hint;
  final Color? hintColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        value,
        if (hint != null) ...[
          const SizedBox(height: 1),
          Text(
            hint!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: hintColor ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
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
    final colorScheme = theme.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

sealed class _FlowRow {
  const _FlowRow();
}

/// 收支两张分类目录的查表封装。
///
/// 目录本身在 build 里 `watch` 一次；行渲染只需要「这条流水的分类是什么」。
class _CategoryIndex {
  const _CategoryIndex({required this.expense, required this.income});

  final MoneyCategoryCatalog expense;
  final MoneyCategoryCatalog income;

  MoneyCategoryEntity? of(MoneyTransactionEntity transaction) {
    final catalog = transaction.type == MoneyTransactionType.income
        ? income
        : expense;
    return catalog.categoryById(transaction.categoryId);
  }
}

class _DayHeaderRow extends _FlowRow {
  const _DayHeaderRow(this.day);

  final DateTime day;
}

class _TransactionRow extends _FlowRow {
  const _TransactionRow(this.transaction);

  final MoneyTransactionEntity transaction;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        _label(day),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }

  String _label(DateTime day) {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return '今天';
    }
    if (diff == 1) {
      return '昨天';
    }
    if (day.year == today.year) {
      return '${day.month}月${day.day}日';
    }
    return '${day.year}年${day.month}月${day.day}日';
  }
}

/// 弹窗里的只读紧凑流水行。
///
/// 刻意**不复用** `TransactionCard`：它要 accounts / 分类目录 / 分期 / 成员 /
/// 账本六个依赖，还带左滑、长按多选、批量条三套交互。这里只需要
/// 「是什么 · 多少钱 · 有没有待确认」，要编辑就点开详情。
class _FlowTransactionRow extends StatelessWidget {
  const _FlowTransactionRow({
    required this.transaction,
    required this.category,
    required this.onTap,
  });

  final MoneyTransactionEntity transaction;
  final MoneyCategoryEntity? category;
  final VoidCallback onTap;

  static const _transferInMarker = 'transfer_in';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final isIncoming = _isIncoming;
    final tone = switch (transaction.type) {
      MoneyTransactionType.income => moneyColors.income,
      MoneyTransactionType.expense => moneyColors.expense,
      MoneyTransactionType.transfer => moneyColors.transfer,
    };
    final iconColor = _iconColor(tone);
    final local = transaction.transactionAt.toLocal();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$_subtitle · ${_two(local.hour)}:${_two(local.minute)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${isIncoming ? '+' : '−'}'
                  '${formatMoneyMinor(_effectiveAmountMinor, transaction.currencyCode)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: transaction.status == MoneyTransactionStatus.pending
                        ? colorScheme.onSurfaceVariant
                        : tone,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                if (_badge case final badge?) ...[
                  const SizedBox(height: 1),
                  Text(
                    badge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _isIncoming {
    if (transaction.type == MoneyTransactionType.income) {
      return true;
    }
    return transaction.type == MoneyTransactionType.transfer &&
        transaction.actualPayerAccount == _transferInMarker;
  }

  /// 与列表金额同口径：扣除退款。
  int get _effectiveAmountMinor {
    final refund = transaction.refundAmountMinor;
    if (refund <= 0) {
      return transaction.amountMinor;
    }
    final net = transaction.amountMinor - refund;
    return net < 0 ? 0 : net;
  }

  String get _title {
    final description = transaction.description.trim();
    if (description.isNotEmpty && !_isGenericDescription(description)) {
      return description;
    }
    final merchant = transaction.merchant?.trim();
    if (merchant != null && merchant.isNotEmpty) {
      return merchant;
    }
    return category?.name ?? transaction.type.label;
  }

  static bool _isGenericDescription(String description) {
    return description == '支出' ||
        description == '收入' ||
        description == '转账' ||
        description == '转入' ||
        description == '转出';
  }

  String get _subtitle {
    if (transaction.type == MoneyTransactionType.transfer) {
      return _isIncoming ? '转账 · 转入' : '转账 · 转出';
    }
    return category?.name ?? transaction.type.label;
  }

  String? get _badge {
    if (transaction.status == MoneyTransactionStatus.pending) {
      return '待确认';
    }
    if (transaction.status == MoneyTransactionStatus.voided) {
      return '已作废';
    }
    if (transaction.installmentPlanId != null &&
        transaction.installmentPlanId!.trim().isNotEmpty) {
      return '分期';
    }
    return null;
  }

  IconData get _icon {
    final category = this.category;
    if (category != null) {
      return materialIconForCategoryIcon(category.icon) ?? _typeIcon;
    }
    return _typeIcon;
  }

  IconData get _typeIcon {
    return switch (transaction.type) {
      MoneyTransactionType.income => Icons.trending_up_rounded,
      MoneyTransactionType.expense => Icons.trending_down_rounded,
      MoneyTransactionType.transfer => Icons.swap_horiz_rounded,
    };
  }

  Color _iconColor(Color tone) {
    final hex = category?.color;
    if (hex == null || hex.trim().isEmpty) {
      return tone;
    }
    return appColorFromHex(hex);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class _EmptyFlow extends StatelessWidget {
  const _EmptyFlow({required this.hasFilter, required this.onReset});

  final bool hasFilter;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasFilter ? '这个筛选下没有流水' : '还没有流水',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 6),
              TextButton(onPressed: onReset, child: const Text('清除筛选')),
            ],
          ],
        ),
      ),
    );
  }
}
