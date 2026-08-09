import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/app_filter_sheet.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_spending_analysis_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_account_distribution_chart.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_account_payment_method_list.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_account_type_distribution_chart.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_category_share_chart.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_member_participation_list.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_budget_execution_card.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_payment_method_chart.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_spending_anomaly_card.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_statistics_rank_list.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_trend_chart.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_time_weekday_pattern_card.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_source_breakdown_card.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_credit_utilization_card.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_budget_history_trend_card.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_upcoming_bills_card.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_upcoming_cashflow_card.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_analysis_report_entity.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_report_card.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_net_worth_trend_card.dart';

final _reportGeneratingProvider =
    NotifierProvider<_ReportGeneratingNotifier, bool>(
      _ReportGeneratingNotifier.new,
    );

class _ReportGeneratingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void start() => state = true;
  void done() => state = false;
}

class MoneyStatisticsSection extends ConsumerWidget {
  const MoneyStatisticsSection({super.key, this.onOpenTransactions});

  final void Function(
    MoneyTransactionQuery query,
    String title,
    String subtitle,
    String? contextLabel,
  )?
  onOpenTransactions;

  String _customRangeLabel(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '自定义';
    final monthSpan = (end.year - start.year) * 12 + (end.month - start.month);
    if (monthSpan == 1 && start.day == 1 && end.day == 1) {
      return '${start.year}年${start.month}月';
    }
    if (start.month == 1 && start.day == 1 && end.month == 1 && end.day == 1) {
      return '${start.year}年';
    }
    return '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} ~ ${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(moneyStatisticsFilterProvider);
    final statisticsContext = ref.watch(moneyStatisticsContextProvider);
    final range = MoneyStatisticsDateRange.resolve(
      filter.periodPreset,
      filter.anchorDate ?? DateTime.now(),
      customStart: filter.customStart,
      customEnd: filter.customEnd,
    );
    final contextValue = statisticsContext.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final ledger = contextValue?.ledger;
    final ledgerName = ledger?.name;
    final periodLabel =
        filter.periodPreset == MoneyStatisticsPeriodPreset.custom
        ? _customRangeLabel(filter.customStart, filter.customEnd)
        : filter.periodPreset.label;
    final statisticsRequest = contextValue != null && contextValue.isReady
        ? MoneyStatisticsRequest(
            userId: contextValue.userId!,
            query: MoneyStatisticsQuery(
              dateStart: range.start,
              dateEndExclusive: range.endExclusive,
              groupBy: range.groupBy,
              ledgerId: contextValue.ledger!.id,
              accountId: filter.accountId,
              accountType: filter.accountType,
              paymentMethod: filter.paymentMethod,
              typeFocus: filter.typeFocus,
            ),
          )
        : null;
    final statistics = statisticsRequest == null
        ? const AsyncValue<MoneyStatisticsSummary>.data(
            MoneyStatisticsSummary.empty(),
          )
        : ref.watch(moneyStatisticsProvider(statisticsRequest));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                [
                  if (ledgerName != null && ledgerName.trim().isNotEmpty)
                    ledgerName,
                  periodLabel,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            AppFilterSheetTrigger(
              title: '筛选统计',
              children: [
                _StatisticsFilterStrip(
                  filter: filter,
                  accounts: statisticsContext.maybeWhen(
                    data: (value) => value.accounts
                        .where((account) => account.isActive)
                        .toList(),
                    orElse: () => const <MoneyAccountEntity>[],
                  ),
                  onPeriodChanged: (value) {
                    ref
                        .read(moneyStatisticsFilterProvider.notifier)
                        .setPeriod(value);
                  },
                  onCustomRangeChanged: (range) {
                    ref
                        .read(moneyStatisticsFilterProvider.notifier)
                        .setCustomRange(range.$1, range.$2);
                  },
                  onTypeFocusChanged: (value) {
                    ref
                        .read(moneyStatisticsFilterProvider.notifier)
                        .setTypeFocus(value);
                  },
                  onAccountChanged: (value) {
                    ref
                        .read(moneyStatisticsFilterProvider.notifier)
                        .setAccountId(value);
                  },
                  onAccountTypeChanged: (value) {
                    ref
                        .read(moneyStatisticsFilterProvider.notifier)
                        .setAccountType(value);
                  },
                  onPaymentMethodChanged: (value) {
                    ref
                        .read(moneyStatisticsFilterProvider.notifier)
                        .setPaymentMethod(value);
                  },
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _StatisticsAsyncBody(
            contextValue: contextValue,
            statisticsContext: statisticsContext,
            statistics: statistics,
            statisticsRequest: statisticsRequest,
            filter: filter,
            range: range,
            groupBy: range.groupBy,
            onOpenTransactions: onOpenTransactions,
          ),
        ),
      ],
    );
  }
}

class _StatisticsAsyncBody extends ConsumerWidget {
  const _StatisticsAsyncBody({
    required this.contextValue,
    required this.statisticsContext,
    required this.statistics,
    required this.statisticsRequest,
    required this.filter,
    required this.range,
    required this.groupBy,
    required this.onOpenTransactions,
  });

  final MoneyStatisticsContext? contextValue;
  final AsyncValue<MoneyStatisticsContext> statisticsContext;
  final AsyncValue<MoneyStatisticsSummary> statistics;
  final MoneyStatisticsRequest? statisticsRequest;
  final MoneyStatisticsFilterState filter;
  final MoneyStatisticsDateRange range;
  final MoneyStatisticsGroupBy groupBy;
  final void Function(
    MoneyTransactionQuery query,
    String title,
    String subtitle,
    String? contextLabel,
  )?
  onOpenTransactions;

  MoneySpendingAnalysisQuery _spendingAnalysisQuery({
    required MoneyStatisticsDateRange range,
    required String ledgerId,
    required MoneyStatisticsFilterState filter,
  }) {
    final windowEnd = DateTime(
      range.endExclusive.year,
      range.endExclusive.month - 1,
    );
    final windowMonths =
        (range.endExclusive.year - range.start.year) * 12 +
        (range.endExclusive.month - range.start.month);
    return MoneySpendingAnalysisQuery(
      currentMonth: windowEnd,
      ledgerId: ledgerId,
      accountId: filter.accountId,
      accountType: filter.accountType,
      paymentMethod: filter.paymentMethod,
      windowMonthCount: windowMonths,
      baselineMonthCount: math.max(windowMonths, 3),
      minimumAmountMinor: filter.anomalyMinAmountMinor,
      minimumGrowthPercent: filter.anomalyMinGrowthPercent,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isContextLoading = statisticsContext.maybeWhen(
      loading: () => true,
      orElse: () => false,
    );
    final hasContextError = statisticsContext.maybeWhen(
      error: (_, _) => true,
      orElse: () => false,
    );

    if (isContextLoading && contextValue == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (hasContextError && contextValue == null) {
      return AppPlainPanel(
        child: AppErrorState(
          title: '读取统计失败',
          onRetry: () => ref.invalidate(moneyStatisticsContextProvider),
        ),
      );
    }

    final readyContext = contextValue;
    final spendingAnalysisRequest = readyContext != null && readyContext.isReady
        ? MoneySpendingAnalysisRequest(
            userId: readyContext.userId!,
            query: _spendingAnalysisQuery(
              range: range,
              ledgerId: readyContext.ledger!.id,
              filter: filter,
            ),
          )
        : null;
    final spendingAnalysis = spendingAnalysisRequest == null
        ? const AsyncValue<MoneySpendingAnalysis>.data(
            MoneySpendingAnalysis.empty(),
          )
        : ref.watch(moneySpendingAnalysisProvider(spendingAnalysisRequest));

    final request = statisticsRequest;
    final insights = request == null
        ? const AsyncValue<MoneyStatisticsInsights>.data(
            MoneyStatisticsInsights.empty(),
          )
        : ref.watch(moneyStatisticsInsightsProvider(request));

    final ledgerId = contextValue?.ledger?.id;
    final budgetHistoryTrend = ledgerId != null
        ? ref.watch(moneyBudgetHistoryTrendProvider(ledgerId))
        : const AsyncValue<List<MoneyBudgetHistoryTrendPoint>>.data(
            <MoneyBudgetHistoryTrendPoint>[],
          );
    final billReminders = ref.watch(currentUserBillRemindersProvider);
    final upcomingCashFlow = ledgerId != null
        ? ref.watch(moneyUpcomingCashFlowProvider(ledgerId))
        : const AsyncValue<MoneyUpcomingCashFlowSummary>.data(
            MoneyUpcomingCashFlowSummary.empty(),
          );

    final latestReport = ledgerId != null
        ? ref.watch(currentUserLatestReportProvider((ledgerId, 'monthly')))
        : const AsyncValue<MoneyAnalysisReportEntity?>.data(null);
    final isGenerating = ref.watch(_reportGeneratingProvider);

    final netWorthTrend = ledgerId != null
        ? ref.watch(currentUserNetWorthTrendProvider((ledgerId, 90)))
        : const AsyncValue<List<MoneyNetWorthTrendPoint>>.data(
            <MoneyNetWorthTrendPoint>[],
          );

    return statistics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => AppPlainPanel(
        child: AppErrorState(
          title: '读取统计失败',
          onRetry: () {
            final request = statisticsRequest;
            if (request != null) {
              ref.invalidate(moneyStatisticsProvider(request));
            } else {
              ref.invalidate(moneyStatisticsContextProvider);
            }
          },
        ),
      ),
      data: (summary) => _StatisticsBody(
        summary: summary,
        filter: filter,
        groupBy: groupBy,
        ledgerId: contextValue?.ledger?.id,
        budgets: ref
            .watch(currentUserBudgetsProvider)
            .maybeWhen(
              data: (value) => value,
              orElse: () => const <MoneyBudgetEntity>[],
            ),
        spendingAnalysis: spendingAnalysis.maybeWhen(
          data: (value) => value,
          orElse: () => const MoneySpendingAnalysis.empty(),
        ),
        insights: insights.maybeWhen(
          data: (value) => value,
          orElse: () => const MoneyStatisticsInsights.empty(),
        ),
        budgetHistoryTrend: budgetHistoryTrend.maybeWhen(
          data: (value) => value,
          orElse: () => const <MoneyBudgetHistoryTrendPoint>[],
        ),
        billReminders: billReminders.maybeWhen(
          data: (value) => value,
          orElse: () => const <MoneyBillReminderEntity>[],
        ),
        accountsById: {
          for (final account
              in contextValue?.accounts ?? const <MoneyAccountEntity>[])
            account.id: account,
        },
        upcomingCashFlow: upcomingCashFlow.maybeWhen(
          data: (value) => value,
          orElse: () => const MoneyUpcomingCashFlowSummary.empty(),
        ),
        latestReport: latestReport.maybeWhen(
          data: (value) => value,
          orElse: () => null,
        ),
        isGenerating: isGenerating,
        netWorthTrend: netWorthTrend.maybeWhen(
          data: (value) => value,
          orElse: () => const <MoneyNetWorthTrendPoint>[],
        ),
        onGenerateReport: () async {
          final id = ledgerId;
          if (id == null || readyContext == null) return;
          ref.read(_reportGeneratingProvider.notifier).start();
          try {
            final now = DateTime.now();
            final repository = ref.read(moneyRepositoryProvider);
            await repository.generateReportForUser(
              readyContext.userId!,
              MoneyAnalysisReportRequest(
                ledgerId: id,
                reportPeriod: 'monthly',
                periodStart: DateTime(now.year, now.month, 1),
                periodEnd: DateTime(now.year, now.month + 1, 1),
              ),
            );
          } catch (_) {
            // 失败状态已写入数据库，invalidate 后报表卡会展示失败态与重试入口。
          } finally {
            ref.invalidate(currentUserLatestReportProvider((id, 'monthly')));
            ref.read(_reportGeneratingProvider.notifier).done();
          }
        },
        onOpenTransactions: onOpenTransactions,
        onAnomalyThresholdChanged: (amountMinor, growthPercent) => ref
            .read(moneyStatisticsFilterProvider.notifier)
            .setAnomalyThresholds(
              minimumAmountMinor: amountMinor,
              minimumGrowthPercent: growthPercent,
            ),
      ),
    );
  }
}

class _StatisticsFilterStrip extends StatelessWidget {
  const _StatisticsFilterStrip({
    required this.filter,
    required this.accounts,
    required this.onPeriodChanged,
    required this.onCustomRangeChanged,
    required this.onTypeFocusChanged,
    required this.onAccountChanged,
    required this.onAccountTypeChanged,
    required this.onPaymentMethodChanged,
  });

  final MoneyStatisticsFilterState filter;
  final List<MoneyAccountEntity> accounts;
  final ValueChanged<MoneyStatisticsPeriodPreset> onPeriodChanged;
  final ValueChanged<(DateTime, DateTime)> onCustomRangeChanged;
  final ValueChanged<MoneyStatisticsTypeFocus> onTypeFocusChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<MoneyAccountType?> onAccountTypeChanged;
  final ValueChanged<MoneyPaymentMethod?> onPaymentMethodChanged;

  int? _customMonth(DateTime? start, DateTime? end) {
    if (start == null || end == null) return null;
    final monthSpan = (end.year - start.year) * 12 + (end.month - start.month);
    if (monthSpan == 1 && start.day == 1 && end.day == 1) {
      return start.month;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final custom = filter.periodPreset == MoneyStatisticsPeriodPreset.custom;
    final customYear = filter.customStart?.year ?? DateTime.now().year;
    final customMonth = _customMonth(filter.customStart, filter.customEnd);
    final closeSheet = AppFilterSheetTrigger.maybeCloserOf(context);
    void apply(VoidCallback onChange) {
      onChange();
      closeSheet?.call();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FormDropdown<MoneyStatisticsPeriodPreset>(
          width: 132,
          label: '周期',
          leadingIcon: const Icon(Icons.date_range_rounded),
          initialSelection: filter.periodPreset,
          entries: [
            for (final value in MoneyStatisticsPeriodPreset.values)
              DropdownMenuEntry(value: value, label: value.label),
          ],
          onSelected: (value) {
            if (value != null) {
              apply(() => onPeriodChanged(value));
            }
          },
        ),
        if (custom) ...[
          FormDropdown<int>(
            key: ValueKey('statistics-year-$customYear'),
            width: 100,
            label: '年份',
            initialSelection: customYear,
            entries: [
              for (
                var y = DateTime.now().year - 10;
                y <= DateTime.now().year + 2;
                y++
              )
                DropdownMenuEntry(value: y, label: '$y年'),
            ],
            onSelected: (value) {
              if (value != null) {
                final month = _customMonth(
                  filter.customStart,
                  filter.customEnd,
                );
                if (month != null) {
                  apply(
                    () => onCustomRangeChanged((
                      DateTime(value, month),
                      DateTime(value, month + 1),
                    )),
                  );
                } else {
                  apply(
                    () => onCustomRangeChanged((
                      DateTime(value),
                      DateTime(value + 1),
                    )),
                  );
                }
              }
            },
          ),
          FormDropdown<int?>(
            key: ValueKey('statistics-month-${customMonth ?? 'all'}'),
            width: 100,
            label: '月份',
            initialSelection: customMonth,
            entries: [
              const DropdownMenuEntry<int?>(value: null, label: '全年'),
              for (var m = 1; m <= 12; m++)
                DropdownMenuEntry<int?>(value: m, label: '$m月'),
            ],
            onSelected: (value) {
              final year = filter.customStart?.year ?? DateTime.now().year;
              if (value != null) {
                apply(
                  () => onCustomRangeChanged((
                    DateTime(year, value),
                    DateTime(year, value + 1),
                  )),
                );
              } else {
                apply(
                  () => onCustomRangeChanged((
                    DateTime(year),
                    DateTime(year + 1),
                  )),
                );
              }
            },
          ),
        ],
        FormDropdown<MoneyStatisticsTypeFocus>(
          width: 124,
          label: '类型',
          leadingIcon: const Icon(Icons.query_stats_rounded),
          initialSelection: filter.typeFocus,
          entries: [
            for (final value in MoneyStatisticsTypeFocus.values)
              DropdownMenuEntry(value: value, label: value.label),
          ],
          onSelected: (value) {
            if (value != null) {
              apply(() => onTypeFocusChanged(value));
            }
          },
        ),
        FormDropdown<String?>(
          width: 176,
          label: '账户',
          leadingIcon: const Icon(Icons.account_balance_wallet_rounded),
          initialSelection: filter.accountId,
          enableFilter: true,
          entries: [
            const DropdownMenuEntry<String?>(value: null, label: '全部账户'),
            for (final account in accounts)
              DropdownMenuEntry<String?>(
                value: account.id,
                label: account.name,
              ),
          ],
          onSelected: (value) => apply(() => onAccountChanged(value)),
        ),
        FormDropdown<MoneyAccountType?>(
          key: ValueKey(
            'statistics-account-type-${filter.accountType?.storageValue ?? 'all'}',
          ),
          width: 148,
          label: '账户类型',
          leadingIcon: const Icon(Icons.category_rounded),
          initialSelection: filter.accountType,
          entries: [
            const DropdownMenuEntry<MoneyAccountType?>(
              value: null,
              label: '全部类型',
            ),
            for (final value in MoneyAccountType.values)
              if (!value.isInternal)
                DropdownMenuEntry<MoneyAccountType?>(
                  value: value,
                  label: value.label,
                ),
          ],
          onSelected: (value) => apply(() => onAccountTypeChanged(value)),
        ),
        FormDropdown<MoneyPaymentMethod?>(
          key: ValueKey(
            'statistics-payment-${filter.paymentMethod?.storageValue ?? 'all'}',
          ),
          width: 144,
          label: '渠道',
          leadingIcon: const Icon(Icons.payments_rounded),
          initialSelection: filter.paymentMethod,
          enableFilter: true,
          entries: [
            const DropdownMenuEntry<MoneyPaymentMethod?>(
              value: null,
              label: '全部渠道',
            ),
            for (final value in MoneyPaymentMethod.values)
              DropdownMenuEntry<MoneyPaymentMethod?>(
                value: value,
                label: value.label,
              ),
          ],
          onSelected: (value) => apply(() => onPaymentMethodChanged(value)),
        ),
      ],
    );
  }
}

class _StatisticsBody extends StatelessWidget {
  const _StatisticsBody({
    required this.summary,
    required this.filter,
    required this.groupBy,
    required this.ledgerId,
    required this.budgets,
    required this.spendingAnalysis,
    required this.insights,
    required this.budgetHistoryTrend,
    required this.billReminders,
    required this.accountsById,
    required this.upcomingCashFlow,
    required this.latestReport,
    required this.isGenerating,
    required this.netWorthTrend,
    required this.onGenerateReport,
    required this.onOpenTransactions,
    required this.onAnomalyThresholdChanged,
  });

  final MoneyStatisticsSummary summary;
  final MoneyStatisticsFilterState filter;
  final MoneyStatisticsGroupBy groupBy;
  final String? ledgerId;
  final List<MoneyBudgetEntity> budgets;
  final MoneySpendingAnalysis spendingAnalysis;
  final MoneyStatisticsInsights insights;
  final List<MoneyBudgetHistoryTrendPoint> budgetHistoryTrend;
  final List<MoneyBillReminderEntity> billReminders;
  final Map<String, MoneyAccountEntity> accountsById;
  final MoneyUpcomingCashFlowSummary upcomingCashFlow;
  final MoneyAnalysisReportEntity? latestReport;
  final bool isGenerating;
  final List<MoneyNetWorthTrendPoint> netWorthTrend;
  final VoidCallback onGenerateReport;
  final void Function(
    MoneyTransactionQuery query,
    String title,
    String subtitle,
    String? contextLabel,
  )?
  onOpenTransactions;
  final void Function(int amountMinor, double growthPercent)
  onAnomalyThresholdChanged;

  static List<MoneyStatisticsRankSlice> _toRankSlices(
    List<MoneyStatisticsTagSlice> tagSlices,
  ) {
    return tagSlices
        .map(
          (s) => MoneyStatisticsRankSlice(
            id: s.tag,
            name: s.tag,
            amountMinor: s.amountMinor,
            transactionCount: s.transactionCount,
            percentage: s.percentage,
          ),
        )
        .toList();
  }

  static const int _pageCount = 5;

  @override
  Widget build(BuildContext context) {
    return _StatisticsPager(
      pageCount: _pageCount,
      pageBuilder: (context, index) => _buildPageContent(context, index),
    );
  }

  Widget _buildPageContent(BuildContext context, int index) {
    return switch (index) {
      0 => _overviewPage(context),
      1 => _spendingPage(context),
      2 => _channelsPage(context),
      3 => _budgetPage(context),
      _ => _accountsPage(context),
    };
  }

  Widget _overviewPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatisticsTotals(summary: summary),
        const SizedBox(height: 12),
        AppContentPanel(
          title: '收支趋势',
          subtitle: _trendSubtitle,
          child: MoneyTrendChart(
            points: summary.trend,
            currencyCode: summary.currencyCode,
            typeFocus: filter.typeFocus,
            groupBy: groupBy,
          ),
        ),
        const SizedBox(height: 12),
        MoneySpendingAnomalyCard(
          analysis: spendingAnalysis,
          minimumAmountMinor: filter.anomalyMinAmountMinor,
          minimumGrowthPercent: filter.anomalyMinGrowthPercent,
          onThresholdChanged: onAnomalyThresholdChanged,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _spendingPage(BuildContext context) {
    final theme = Theme.of(context);
    final showIncomeCategories =
        filter.typeFocus == MoneyStatisticsTypeFocus.income;
    final categoryTitle = showIncomeCategories ? '收入分类' : '支出分类';
    final categorySubtitle = showIncomeCategories ? '按分类汇总收入占比' : '按分类汇总支出占比';
    final categorySlices = showIncomeCategories
        ? summary.incomeCategories
        : summary.expenseCategories;
    final categoryColor = showIncomeCategories
        ? theme.moneyColors.income
        : theme.moneyColors.expense;
    final subCategoryTitle = showIncomeCategories ? '收入二级分类' : '支出二级分类';
    final subCategorySubtitle = showIncomeCategories
        ? '更具体地看收入来源'
        : '更具体地看支出流向';
    final subCategorySlices = showIncomeCategories
        ? summary.incomeSubCategories
        : summary.expenseSubCategories;
    final subCategoryEmptyTitle = showIncomeCategories
        ? '暂无收入二级分类数据'
        : '暂无支出二级分类数据';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppContentPanel(
          title: categoryTitle,
          subtitle: categorySubtitle,
          child: MoneyCategoryShareChart(
            slices: categorySlices,
            currencyCode: summary.currencyCode,
            emptyTitle: showIncomeCategories ? '暂无收入分类数据' : '暂无支出分类数据',
            centerLabel: showIncomeCategories ? '总收入' : '总支出',
            baseColor: categoryColor,
            onSliceTap: onOpenTransactions == null
                ? null
                : (slice) => _openTransactions(
                    query: MoneyTransactionQuery(
                      ledgerId: ledgerId,
                      type: _categoryTypeForFocus(),
                      categoryId: slice.categoryId,
                    ),
                    title: categoryTitle,
                    subtitle: slice.categoryName,
                    contextLabel: null,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        AppContentPanel(
          title: subCategoryTitle,
          subtitle: subCategorySubtitle,
          child: MoneyStatisticsRankList(
            slices: subCategorySlices,
            currencyCode: summary.currencyCode,
            emptyTitle: subCategoryEmptyTitle,
            onSliceTap: onOpenTransactions == null
                ? null
                : (slice) => _openTransactions(
                    query: MoneyTransactionQuery(
                      ledgerId: ledgerId,
                      type: _categoryTypeForFocus(),
                      subCategoryId: slice.id,
                    ),
                    title: subCategoryTitle,
                    subtitle: slice.name,
                    contextLabel: null,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        AppContentPanel(
          title: '商家排行',
          subtitle: '按商家汇总支出金额',
          child: MoneyStatisticsRankList(
            slices: summary.merchants,
            currencyCode: summary.currencyCode,
            emptyTitle: '暂无商家数据',
            onSliceTap: onOpenTransactions == null
                ? null
                : (slice) => _openTransactions(
                    query: MoneyTransactionQuery(
                      ledgerId: ledgerId,
                      type: MoneyTransactionType.expense,
                      merchant: slice.name,
                    ),
                    title: '商家流水',
                    subtitle: slice.name,
                    contextLabel: null,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        AppContentPanel(
          title: '标签排行',
          subtitle: '按标签汇总支出金额',
          child: MoneyStatisticsRankList(
            slices: _toRankSlices(insights.tagSlices),
            currencyCode: insights.currencyCode,
            emptyTitle: '暂无标签数据',
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _channelsPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppContentPanel(
          title: '支付渠道',
          subtitle: '按支付方式汇总金额、占比和笔数',
          child: MoneyPaymentMethodChart(
            slices: summary.paymentMethods,
            currencyCode: summary.currencyCode,
            onSliceTap: onOpenTransactions == null
                ? null
                : (slice) => _openTransactions(
                    query: MoneyTransactionQuery(
                      ledgerId: ledgerId,
                      type: _typeForFocus(),
                      paymentMethod: slice.paymentMethod,
                      customPaymentMethodName: slice.customPaymentMethodName,
                    ),
                    title: '渠道流水',
                    subtitle: slice.label,
                    contextLabel: null,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        AppContentPanel(
          title: '账户渠道',
          subtitle: '按账户和支付方式交叉汇总金额',
          child: MoneyAccountPaymentMethodList(
            slices: summary.accountPaymentMethods,
            currencyCode: summary.currencyCode,
            onSliceTap: onOpenTransactions == null
                ? null
                : (slice) => _openTransactions(
                    query: MoneyTransactionQuery(
                      ledgerId: ledgerId,
                      type: _typeForFocus(),
                      accountId: slice.accountId,
                      paymentMethod: slice.paymentMethod,
                    ),
                    title: '账户渠道流水',
                    subtitle:
                        '${slice.accountName} · ${slice.paymentMethodLabel}',
                    contextLabel: null,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        MoneyTimeWeekdayPatternCard(insights: insights),
        const SizedBox(height: 12),
        MoneySourceBreakdownCard(insights: insights),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _budgetPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoneyBudgetExecutionCard(budgets: budgets),
        const SizedBox(height: 12),
        MoneyBudgetHistoryTrendCard(points: budgetHistoryTrend),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _accountsPage(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppContentPanel(
          title: '账户分布',
          subtitle: '当前活跃账户资产与负债',
          child: MoneyAccountDistributionChart(
            slices: summary.accounts,
            onAccountTap: onOpenTransactions == null
                ? null
                : (slice) => _openTransactions(
                    query: MoneyTransactionQuery(
                      ledgerId: ledgerId,
                      accountId: slice.accountId,
                    ),
                    title: '账户流水',
                    subtitle: slice.accountName,
                    contextLabel: null,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        AppContentPanel(
          title: '账户类型',
          subtitle: '按账户类型汇总资产与负债',
          child: MoneyAccountTypeDistributionChart(
            slices: summary.accountTypes,
          ),
        ),
        const SizedBox(height: 12),
        MoneyCreditUtilizationCard(insights: insights),
        const SizedBox(height: 12),
        MoneyNetWorthTrendCard(points: netWorthTrend),
        const SizedBox(height: 12),
        MoneyUpcomingBillsCard(
          bills: billReminders,
          accountsById: accountsById,
        ),
        const SizedBox(height: 12),
        MoneyUpcomingCashFlowCard(summary: upcomingCashFlow),
        if (summary.familyMembers.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppContentPanel(
            title: '成员参与',
            subtitle: '按分摊记录汇总已付、参与和净额',
            child: MoneyMemberParticipationList(
              slices: summary.familyMembers,
              currencyCode: summary.currencyCode,
            ),
          ),
        ],
        const SizedBox(height: 12),
        MoneyReportCard(
          latestReport: latestReport,
          isGenerating: isGenerating,
          onGenerate: onGenerateReport,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String get _trendSubtitle {
    final type = filter.typeFocus.label;
    final group = groupBy == MoneyStatisticsGroupBy.day ? '按日' : '按月';
    return '$type · $group';
  }

  MoneyTransactionType? _typeForFocus() {
    return switch (filter.typeFocus) {
      MoneyStatisticsTypeFocus.income => MoneyTransactionType.income,
      MoneyStatisticsTypeFocus.expense => MoneyTransactionType.expense,
      MoneyStatisticsTypeFocus.balance => null,
    };
  }

  MoneyTransactionType _categoryTypeForFocus() {
    return switch (filter.typeFocus) {
      MoneyStatisticsTypeFocus.income => MoneyTransactionType.income,
      MoneyStatisticsTypeFocus.expense => MoneyTransactionType.expense,
      MoneyStatisticsTypeFocus.balance => MoneyTransactionType.expense,
    };
  }

  void _openTransactions({
    required MoneyTransactionQuery query,
    required String title,
    required String subtitle,
    String? contextLabel,
  }) {
    final callback = onOpenTransactions;
    if (callback == null) {
      return;
    }
    callback(query, title, subtitle, contextLabel);
  }
}

class _StatisticsPager extends StatefulWidget {
  const _StatisticsPager({required this.pageCount, required this.pageBuilder});

  final int pageCount;
  final Widget Function(BuildContext context, int index) pageBuilder;

  @override
  State<_StatisticsPager> createState() => _StatisticsPagerState();
}

class _StatisticsPagerState extends State<_StatisticsPager> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page == _currentPage) {
      return;
    }
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PageDots(
          count: widget.pageCount,
          current: _currentPage,
          onTap: _goToPage,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            physics: const BouncingScrollPhysics(),
            allowImplicitScrolling: true,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.pageCount,
            itemBuilder: (context, index) {
              return _KeepAliveStatisticsPage(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      widget.pageBuilder(context, index),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _KeepAliveStatisticsPage extends StatefulWidget {
  const _KeepAliveStatisticsPage({required this.child});

  final Widget child;

  @override
  State<_KeepAliveStatisticsPage> createState() =>
      _KeepAliveStatisticsPageState();
}

class _KeepAliveStatisticsPageState extends State<_KeepAliveStatisticsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.onTap,
  });

  final int count;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index += 1)
          GestureDetector(
            key: ValueKey<String>('statistics-dot-$index'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: index == current ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatisticsTotals extends StatelessWidget {
  const _StatisticsTotals({required this.summary});

  final MoneyStatisticsSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) {
      return AppPlainPanel(
        child: AppEmptyState(
          icon: Icons.account_balance_wallet_rounded,
          title: '暂无收支数据',
          message: '此时间范围内没有交易记录。',
        ),
      );
    }

    final theme = Theme.of(context);
    final moneyColors = theme.moneyColors;

    return AppPlainPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = AppResponsive.of(
            context,
            width: constraints.maxWidth,
          ).isCompact;

          final incomePanel = _MetricPanel(
            label: '收入',
            currentMinor: summary.totalIncomeMinor,
            color: moneyColors.income,
            icon: Icons.trending_up_rounded,
            count: summary.incomeTransactionCount,
            averageMinor: summary.averageIncomeMinor,
            currencyCode: summary.currencyCode,
            previousMinor: summary.previousPeriod.incomeMinor,
            sameYearMinor: summary.samePeriodLastYear.incomeMinor,
          );
          final expensePanel = _MetricPanel(
            label: '支出',
            currentMinor: summary.totalExpenseMinor,
            color: moneyColors.expense,
            icon: Icons.trending_down_rounded,
            count: summary.expenseTransactionCount,
            averageMinor: summary.averageExpenseMinor,
            currencyCode: summary.currencyCode,
            previousMinor: summary.previousPeriod.expenseMinor,
            sameYearMinor: summary.samePeriodLastYear.expenseMinor,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    incomePanel,
                    const SizedBox(height: 12),
                    expensePanel,
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: incomePanel),
                    const SizedBox(width: 12),
                    Expanded(child: expensePanel),
                  ],
                ),
              const SizedBox(height: 14),
              Container(height: 1, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 14),
              _buildNetSection(theme, moneyColors),
              if (summary.hasMixedCurrencies) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '已按主要币种展示',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildNetSection(ThemeData theme, AppMoneyColors moneyColors) {
    final isPositive = summary.netMinor >= 0;
    final netColor = isPositive
        ? theme.colorScheme.primary
        : moneyColors.expense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '净余额',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              formatMoneyMinor(summary.netMinor, summary.currencyCode),
              style: theme.textTheme.titleLarge?.copyWith(
                color: netColor,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _ComparisonChip(
              label: '较前期',
              currentMinor: summary.netMinor,
              baselineMinor: summary.previousPeriod.netMinor,
            ),
            _ComparisonChip(
              label: '同比',
              currentMinor: summary.netMinor,
              baselineMinor: summary.samePeriodLastYear.netMinor,
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({
    required this.label,
    required this.currentMinor,
    required this.color,
    required this.icon,
    required this.count,
    required this.averageMinor,
    required this.currencyCode,
    required this.previousMinor,
    required this.sameYearMinor,
  });

  final String label;
  final int currentMinor;
  final Color color;
  final IconData icon;
  final int count;
  final int averageMinor;
  final String currencyCode;
  final int previousMinor;
  final int sameYearMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.all(14),
      backgroundColor: color.withValues(alpha: 0.10),
      borderColor: color.withValues(alpha: 0.20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            formatMoneyMinor(currentMinor, currencyCode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _countText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ComparisonChip(
                label: '较前期',
                currentMinor: currentMinor,
                baselineMinor: previousMinor,
              ),
              _ComparisonChip(
                label: '同比',
                currentMinor: currentMinor,
                baselineMinor: sameYearMinor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _countText {
    if (count == 0) return '0 笔';
    return '$count 笔 · 均 ${formatMoneyMinor(averageMinor, currencyCode)}';
  }
}

class _ComparisonChip extends StatelessWidget {
  const _ComparisonChip({
    required this.label,
    required this.currentMinor,
    required this.baselineMinor,
  });

  final String label;
  final int currentMinor;
  final int baselineMinor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moneyColors = theme.moneyColors;

    bool isNeutral;
    bool isPositive;
    String text;

    if (baselineMinor == 0) {
      isNeutral = true;
      isPositive = false;
      text = currentMinor == 0 ? '$label 持平' : '$label 新增';
    } else {
      final delta = currentMinor - baselineMinor;
      if (delta == 0) {
        isNeutral = true;
        isPositive = false;
        text = '$label 持平';
      } else {
        isNeutral = false;
        isPositive = delta > 0;
        final percent = delta.abs() / baselineMinor.abs() * 100;
        final precision = percent >= 10 ? 0 : 1;
        final arrow = delta > 0 ? '↑' : '↓';
        text = '$arrow${percent.toStringAsFixed(precision)}% $label';
      }
    }

    final chipColor = isNeutral
        ? theme.colorScheme.onSurfaceVariant
        : isPositive
        ? moneyColors.income
        : moneyColors.expense;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: chipColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
