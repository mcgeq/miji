import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/life_energy/application/life_energy_format.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_commitment_entity.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/quick_entry_sheet.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/domain/wishlist_insight.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/presentation/wishlist_detail_sheet.dart';
import 'package:miji/features/life_energy/presentation/wishlist_entry_sheet.dart';
import 'package:miji/features/life_energy/presentation/wishlist_status_chip.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';

enum _WishlistSort {
  recent('recent', '最近加入'),
  cost('cost', '代价最高'),
  desire('desire', '最想要'),
  dueSoon('dueSoon', '快到期');

  const _WishlistSort(this.storage, this.label);

  /// 存进 `life_energy_prefs` 的值。用字符串而不是 index：枚举顺序一改，
  /// 存下来的偏好就会指向另一个选项。
  final String storage;
  final String label;

  static _WishlistSort fromStorage(String? raw) {
    for (final value in values) {
      if (value.storage == raw) {
        return value;
      }
    }
    return recent;
  }
}

/// 想买清单（面板「想买」那一段的全部内容）。
///
/// 每一行右侧的「4.1 个工作日」是这一页的主角，字号比金额大：金额是用户已经
/// 熟悉的信息，天数才是新信息。
///
/// 为什么分成「可以决定 / 冷却中 / 已结束」三组：这不是一个平铺的收藏夹，是
/// 一个**等着做决定**的队列。混在一起时，冷静期里的东西和已经到期的东西长得
/// 一模一样，用户既看不出「今天该决定哪几件」，也会在一条条灰掉的已放弃里
/// 迷路。已结束的默认折叠 —— 它们只在复盘时有用。
///
/// 清单**不进流水、不进预算**，页脚那行小字必须写 —— 否则用户会担心它污染账本。
/// 清单本体：汇总条 + 分组 + 每一件 + 空态/错误态。
///
/// 自带排序与「已结束折叠」两个状态：它们属于**列表**，不属于宿主页面。
class WishlistListBody extends ConsumerStatefulWidget {
  const WishlistListBody({super.key, this.onAdd});

  /// 「加一件」的动作。null 时用默认的底部弹层（页面和面板都能直接用）。
  final VoidCallback? onAdd;

  @override
  ConsumerState<WishlistListBody> createState() => _WishlistListBodyState();
}

class _WishlistListBodyState extends ConsumerState<WishlistListBody> {
  /// 用户在这一页刚选的排序。null = 用偏好里存的（默认「最近加入」）。
  ///
  /// 为什么要本地兜一层：偏好是异步读来的，点一下排序就等一次数据库往返，
  /// 列表会闪一下重新排。本地先改、写库在后台。
  _WishlistSort? _sortOverride;

  /// 已结束的默认收起：它们只在复盘时有意义，不该每天占掉半屏。
  bool _settledExpanded = false;

  _WishlistSort get _sort =>
      _sortOverride ??
      _WishlistSort.fromStorage(ref.watch(lifeEnergyPrefsProvider).sort);

  void _selectSort(_WishlistSort sort) {
    setState(() => _sortOverride = sort);
    final prefs = ref.read(lifeEnergyPrefsProvider);
    ref
        .read(lifeEnergyActionsProvider)
        .saveLifeEnergyPrefs(prefs.copyWith(sort: sort.storage));
  }

  void _add() {
    final handler = widget.onAdd;
    if (handler != null) {
      handler();
      return;
    }
    showWishlistEntrySheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = theme.spacingTokens;
    final entriesAsync = ref.watch(currentWishlistProvider);
    final profile = ref.watch(currentWorkProfileProvider).asData?.value;
    final insight = ref.watch(currentWishlistInsightProvider);
    final now = ref.watch(lifeEnergyClockProvider)();
    // 决定买不买的真正约束是「这个月还剩多少能自由支配」，不是清单合计。
    // 三个数都来自记账：到手来自收入与工时，已花来自本月流水，还要付来自
    // 自动记账 / 分期 / 账单（和「预算已预留」用的是同一套来源）。
    final monthSummary = ref
        .watch(currentMonthMoneySummaryProvider)
        .asData
        ?.value;
    final committed = ref.watch(currentCommittedExpenseProvider).asData?.value;

    return entriesAsync.when(
      loading: () => const AppSkeletonList(rows: 5),
      error: (error, stackTrace) => AppErrorState(
        title: '读取想买清单失败',
        onRetry: () => ref.invalidate(currentWishlistProvider),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return AppEmptyState(
            title: '还没有想买的东西',
            message: '把犹豫的东西先记下来，冷却几天再决定。',
            icon: Icons.shopping_bag_outlined,
            action: FilledButton(onPressed: _add, child: const Text('加一件想买的')),
          );
        }
        final groups = _group(entries, now);
        final totalDays = insight?.totalWorkdays ?? 0;
        // 分段条的两段：按状态直接算，不靠组标题反查（标题改一个字就错）。
        double daysWhere(WishlistItemStatus status) {
          if (profile == null) {
            return 0;
          }
          var sum = 0.0;
          for (final entry in entries) {
            if (entry.statusAt(now) == status) {
              sum += entry.daysFor(profile) ?? 0;
            }
          }
          return sum;
        }

        final readyDays = daysWhere(WishlistItemStatus.ready);
        final waitingDays = daysWhere(WishlistItemStatus.waiting);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            spacing.pageCompact,
            8,
            spacing.pageCompact,
            32,
          ),
          children: [
            Row(
              children: [
                PopupMenuButton<_WishlistSort>(
                  tooltip: '排序',
                  initialValue: _sort,
                  onSelected: _selectSort,
                  itemBuilder: (context) => [
                    for (final option in _WishlistSort.values)
                      PopupMenuItem<_WishlistSort>(
                        value: option,
                        child: Text(option.label),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _sort.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('加一件'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (insight != null && insight.activeCount > 0)
              _SummaryBar(
                insightCount: insight.activeCount,
                totalAmountMinor: insight.totalAmountMinor,
                totalWorkdays: insight.totalWorkdays,
                readyDays: readyDays,
                waitingDays: waitingDays,
                daysKnown: insight.daysKnown,
                waitingCount: insight.waitingCount,
                readyCount: insight.readyCount,
                currencyCode: profile?.currencyCode ?? 'CNY',
                wageMinor: profile?.hourlyWageMinor ?? 0,
                month: now.month,
                takeHomeMinor: profile?.monthlyGrossMinor.round(),
                spentMinor: monthSummary?.expenseMinor,
                committedMinor: committed?.thisMonthMinor,
                committedItems: committed?.thisMonth,
                nextMonthMinor: committed?.nextMonthMinor,
                nextMonthItems: committed?.nextMonth,
              ),
            for (final group in groups) ...[
              const SizedBox(height: 14),
              _GroupHeader(
                title: group.title,
                count: group.entries.length,
                detail: group.detail,
              ),
              const SizedBox(height: 8),
              if (group.collapsible && !_settledExpanded)
                _CollapsedHint(
                  label: '点开看 ${group.entries.length} 件已结束的',
                  onTap: () => setState(() => _settledExpanded = true),
                )
              else
                for (final entry in group.entries) ...[
                  _WishlistRow(
                    entry: entry,
                    profile: profile,
                    now: now,
                    shareDays: totalDays <= 0 || profile == null
                        ? null
                        : entry.daysFor(profile),
                    totalDays: totalDays,
                    insight: insight,
                    onOpen: () => _openDetail(entry, insight, now),
                    onEdit: () => showWishlistEntrySheet(context, entry: entry),
                    onSettle: (status) => _settle(entry, status),
                    onDelete: () => _delete(entry),
                  ),
                  const SizedBox(height: 10),
                ],
              if (group.collapsible && _settledExpanded)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _settledExpanded = false),
                    child: const Text('收起已结束的'),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              '清单项不是支出：不进流水、不进统计、不影响预算。'
              '只有标记「买了」并记一笔时，才会落一条正常流水。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
                letterSpacing: 0,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 三组：可以决定（最上）/ 冷却中 / 已结束。
  ///
  /// 组内仍按用户选的排序排；组本身固定顺序 —— 「今天能决定哪几件」不该受
  /// 排序方式影响。
  List<_WishlistGroup> _group(List<WishlistEntry> entries, DateTime now) {
    final ready = <WishlistEntry>[];
    final waiting = <WishlistEntry>[];
    final settled = <WishlistEntry>[];
    for (final entry in _sorted(entries, now)) {
      switch (entry.statusAt(now)) {
        case WishlistItemStatus.ready:
          ready.add(entry);
        case WishlistItemStatus.waiting:
          waiting.add(entry);
        case WishlistItemStatus.bought:
        case WishlistItemStatus.dropped:
          settled.add(entry);
      }
    }
    return [
      if (ready.isNotEmpty)
        _WishlistGroup(title: '可以决定', entries: ready, detail: '冷却期已过，该做决定了'),
      if (waiting.isNotEmpty)
        _WishlistGroup(title: '冷却中', entries: waiting, detail: '先放几天，别当场决定'),
      if (settled.isNotEmpty)
        _WishlistGroup(title: '已结束', entries: settled, collapsible: true),
    ];
  }

  Future<void> _openDetail(
    WishlistEntry entry,
    WishlistInsight? insight,
    DateTime now,
  ) {
    return showWishlistDetailSheet(
      context,
      entry: entry,
      insight: insight,
      onSettle: (status) => _settle(entry, status),
      onEdit: () => showWishlistEntrySheet(context, entry: entry),
      onDelete: () => _delete(entry),
    );
  }

  List<WishlistEntry> _sorted(List<WishlistEntry> entries, DateTime now) {
    final sorted = [...entries];
    switch (_sort) {
      case _WishlistSort.recent:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _WishlistSort.cost:
        sorted.sort(
          (a, b) => b.targetAmountMinor.compareTo(a.targetAmountMinor),
        );
      case _WishlistSort.desire:
        sorted.sort((a, b) => b.desire.index.compareTo(a.desire.index));
      case _WishlistSort.dueSoon:
        sorted.sort((a, b) {
          final aUntil = a.cooldownUntil;
          final bUntil = b.cooldownUntil;
          if (aUntil == null && bUntil == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (aUntil == null) {
            return 1;
          }
          if (bUntil == null) {
            return -1;
          }
          return aUntil.compareTo(bUntil);
        });
    }
    return sorted;
  }

  Future<void> _settle(WishlistEntry entry, WishlistItemStatus status) async {
    // 买了之后问一句要不要记一笔：清单本来就是为了「买之前想清楚」，
    // 真买了却要用户跑到记账页重打一遍金额和名字，这一步一定会漏。
    String? transactionId;
    if (status == WishlistItemStatus.bought) {
      transactionId = await _recordPurchase(entry);
      if (!mounted) {
        return;
      }
    }
    await ref
        .read(lifeEnergyActionsProvider)
        .settleWishlistItem(entry, status, transactionId: transactionId);
    if (!mounted) {
      return;
    }
    // 放弃时只返回一条「省下 X 个工作日」，不弹庆祝、不说「真棒」。
    // 这个功能的立场是让代价可见，不是替用户做决定。
    if (status == WishlistItemStatus.dropped) {
      final profile = ref.read(currentWorkProfileProvider).asData?.value;
      final days = profile == null ? null : entry.daysFor(profile);
      if (days != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('省下 ${formatLifeEnergyWorkdays(days)} 个工作日')),
        );
      }
    }
  }

  /// 问「记一笔吗」，记完返回那笔流水的 id；不记返回 null。
  ///
  /// 记不记都算「买了」——这一步是**顺手**，不是前置条件。所以没有「取消就
  /// 不算买了」的选项：那样用户得先想清楚要不要记账，才能标记买了。
  Future<String?> _recordPurchase(WishlistEntry entry) async {
    final profile = ref.read(currentWorkProfileProvider).asData?.value;
    final amountText = profile == null
        ? null
        : formatMoneyMinor(entry.targetAmountMinor, profile.currencyCode);
    final record = await showAppConfirmDialog(
      context: context,
      title: '记一笔流水吗？',
      message: amountText == null
          ? '把「${entry.title}」记成这个月的一笔支出。'
          : '把「${entry.title}」$amountText 记成这个月的一笔支出。',
      confirmLabel: '记一笔',
      cancelLabel: '先不记',
    );
    if (!record || !mounted) {
      return null;
    }
    final created = await showQuickEntrySheet(
      context,
      initialAmountMinor: entry.targetAmountMinor,
      initialDescription: entry.title,
    );
    return created?.id;
  }

  Future<void> _delete(WishlistEntry entry) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除这一项',
      message: '从清单里删除「${entry.title}」？',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await ref.read(lifeEnergyActionsProvider).deleteWishlistItem(entry);
  }
}

/// 清单合计：一件件加起来到底要干多久。
///
/// 原来的版本是四行左对齐的灰字（标题 / 件数金额 / 天数 / 口径），读起来像一张
/// 规格表，主数字和辅助信息一个字号级别。现在改成两列：左边钱、右边时间 ——
/// **时间才是这一页要说的那句话**，放大到能一眼看见；钱退到它下面一行当注脚。
///
/// 底下那条分段条把「可以决定 / 冷却中」画成比例，而不是再写一行
/// 「冷却中 2 · 可以决定 2」：同样的信息，条形能让人直接看出「已经能决定的有多少」。
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.insightCount,
    required this.totalAmountMinor,
    required this.totalWorkdays,
    required this.readyDays,
    required this.waitingDays,
    required this.daysKnown,
    required this.waitingCount,
    required this.readyCount,
    required this.currencyCode,
    required this.wageMinor,
    required this.month,
    required this.takeHomeMinor,
    required this.spentMinor,
    required this.committedMinor,
    required this.committedItems,
    required this.nextMonthMinor,
    required this.nextMonthItems,
  });

  final int insightCount;
  final int totalAmountMinor;
  final double totalWorkdays;

  /// 分组各自的天数合计：分段条的两段。
  final double readyDays;
  final double waitingDays;

  final bool daysKnown;
  final int waitingCount;
  final int readyCount;
  final String currencyCode;

  /// 折算用的时薪（当月）。写在口径行里，不是装饰。
  final double wageMinor;

  /// 折算是**按月**的时薪算的：不带月份，用户 1 月看到 4.0、7 月看到 4.2，
  /// 会以为功能在乱跳 —— 其实是他在不同月份问的同一个问题。
  final int month;

  /// 本月到手（分）。null = 档案还没填。
  final int? takeHomeMinor;

  /// 本月已经记过的支出（分）。null = 还没读到。
  final int? spentMinor;

  /// 本月**还没入账**的支出义务（分）：自动记账 / 分期 / 账单 / 待确认。
  final int? committedMinor;

  /// 这些义务是哪几笔。只给「还要付」那行展示前 2 条的标题。
  final List<MoneyBudgetCommitmentItem>? committedItems;

  /// 下个月整月的固定支出（分 / 笔数）。只说是什么、不说「余量」——
  /// 下个月还有没有收入、会不会涨薪，这一页不知道。
  final int? nextMonthMinor;
  final List<MoneyBudgetCommitmentItem>? nextMonthItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final money = theme.moneyColors;
    final spacing = theme.spacingTokens;
    final disposable = _disposable;

    return AppSurface(
      padding: EdgeInsets.all(spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '清单上的代价',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$insightCount 件',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 钱：用户已经熟悉的信息，放左边当参照。
                    Text(
                      formatMoneyMinor(totalAmountMinor, currencyCode),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      daysKnown
                          ? '合计 · 按 $month 月 '
                                '${formatLifeEnergyWage(wageMinor, currencyCode)} / 小时'
                          : '合计',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (daysKnown) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatLifeEnergyWorkdays(totalWorkdays),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      '个工作日',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (daysKnown && totalWorkdays > 0) ...[
            const SizedBox(height: 12),
            _SplitBar(
              readyDays: readyDays,
              waitingDays: waitingDays,
              totalDays: totalWorkdays,
              readyColor: money.incomeStrong,
              waitingColor: money.warningStrong,
              trackColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _LegendDot(
                  color: money.incomeStrong,
                  label:
                      '可以决定 $readyCount 件 · '
                      '${formatLifeEnergyWorkdays(readyDays)} 天',
                ),
                const SizedBox(width: 12),
                _LegendDot(
                  color: money.warningStrong,
                  label:
                      '冷却中 $waitingCount 件 · '
                      '${formatLifeEnergyWorkdays(waitingDays)} 天',
                ),
              ],
            ),
          ],
          if (disposable != null) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            _DisposableBlock(
              disposableMinor: disposable,
              takeHomeMinor: takeHomeMinor!,
              spentMinor: spentMinor!,
              committedMinor: committedMinor!,
              listTotalMinor: totalAmountMinor,
              committedItems: committedItems ?? const [],
              nextMonthMinor: nextMonthMinor ?? 0,
              nextMonthItems: nextMonthItems ?? const [],
              currencyCode: currencyCode,
            ),
          ],
        ],
      ),
    );
  }

  /// 本月还能自由支配的钱 = 到手 − 已发生支出 − 还没入账的固定账单。
  ///
  /// 三个数都能在上面那行小字里找到出处，用户可以对账；这也是它不进时薪的
  /// 原因 —— 时薪是汇率（一小时换多少钱），这里是**余额**（这个月还剩多少），
  /// 两个量混在一起会算出负数时薪（房贷比工资还高的月份），而余额为负是
  /// 一个真实现象，说得清。
  int? get _disposable {
    final takeHome = takeHomeMinor;
    final spent = spentMinor;
    final committed = committedMinor;
    if (takeHome == null || spent == null || committed == null) {
      return null;
    }
    return takeHome - spent - committed;
  }
}

/// 「本月还能自由花」：清单合计跟它比，才知道要不要动存款。
class _DisposableBlock extends StatelessWidget {
  const _DisposableBlock({
    required this.disposableMinor,
    required this.takeHomeMinor,
    required this.spentMinor,
    required this.committedMinor,
    required this.listTotalMinor,
    required this.committedItems,
    required this.nextMonthMinor,
    required this.nextMonthItems,
    required this.currencyCode,
  });

  final int disposableMinor;
  final int takeHomeMinor;
  final int spentMinor;
  final int committedMinor;
  final int listTotalMinor;
  final List<MoneyBudgetCommitmentItem> committedItems;
  final int nextMonthMinor;
  final List<MoneyBudgetCommitmentItem> nextMonthItems;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final negative = disposableMinor <= 0;
    final ratio = disposableMinor > 0 ? listTotalMinor / disposableMinor : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '本月还能自由花',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              formatMoneyMinor(disposableMinor, currencyCode),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: negative ? colorScheme.error : colorScheme.onSurface,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '到手 ${formatMoneyMinor(takeHomeMinor, currencyCode)}'
          ' − 已花 ${formatMoneyMinor(spentMinor, currencyCode)}'
          ' − 还要付 ${formatMoneyMinor(committedMinor, currencyCode)}'
          '${committedItems.isEmpty ? '' : '（${_commitmentHint(committedItems)}）'}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.35,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          negative
              ? '这个月已经没有余量了 —— 清单上的东西，买哪件都要动存款。'
              : '清单合计是它的 ${ratio!.toStringAsFixed(ratio >= 10 ? 0 : 1)} 倍。',
          style: theme.textTheme.labelSmall?.copyWith(
            color: negative ? colorScheme.error : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.35,
          ),
        ),
        if (nextMonthMinor > 0) ...[
          const SizedBox(height: 2),
          Text(
            '下月还要付 ${formatMoneyMinor(nextMonthMinor, currencyCode)}'
            '${nextMonthItems.isEmpty ? '' : '（${_commitmentHint(nextMonthItems)}）'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  /// 「还要付」是哪几笔：只写前两条 + 一个总数。
  ///
  /// 给明细是跟预算卡学的：只给「已预留 ¥4,200」用户会怀疑，看到
  /// 「房租 25 日 3,000 + 分期第 3 期 1,200」才敢信。
  String _commitmentHint(List<MoneyBudgetCommitmentItem> items) {
    final titles = items
        .take(2)
        .map((item) => '${item.title} ${item.date.day} 日')
        .join(' · ');
    final rest = items.length - 2;
    return rest > 0 ? '$titles 等 ${items.length} 笔' : titles;
  }
}

/// 一段两色的细条：可以决定 / 冷却中的天数占比。
///
/// 两段都为 0 时退回空轨道，不画满格 —— 满格会被读成「已经全部到期」。
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.readyDays,
    required this.waitingDays,
    required this.totalDays,
    required this.readyColor,
    required this.waitingColor,
    required this.trackColor,
  });

  final double readyDays;
  final double waitingDays;
  final double totalDays;
  final Color readyColor;
  final Color waitingColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    final ready = readyDays <= 0 ? 0 : (readyDays / totalDays * 1000).round();
    final waiting = waitingDays <= 0
        ? 0
        : (waitingDays / totalDays * 1000).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            if (ready > 0)
              Expanded(
                flex: ready,
                child: ColoredBox(color: readyColor),
              ),
            if (waiting > 0)
              Expanded(
                flex: waiting,
                child: ColoredBox(color: waitingColor),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishlistGroup {
  const _WishlistGroup({
    required this.title,
    required this.entries,
    this.detail,
    this.collapsible = false,
  });

  final String title;
  final List<WishlistEntry> entries;
  final String? detail;
  final bool collapsible;
}

/// 组标题：件数 + 一句口径。件数用零宽空格隔开，免得 3 件 的 3 黏在标题上。
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.count, this.detail});

  final String title;
  final int count;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$title · $count 件',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CollapsedHint extends StatelessWidget {
  const _CollapsedHint({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.zero,
        foregroundColor: theme.colorScheme.onSurfaceVariant,
      ),
      child: Text(label),
    );
  }
}

/// 一件想买的东西（列表行）。
///
/// 四层信息，按「决定时需要什么」排序：
/// 1. 想要程度 + 名字 + 状态 —— 这是哪一件、现在能不能决定；
/// 2. 代价 —— 多少工作日 / 多少小时 / 多少钱，天数最大；
/// 3. 只在这一件里才有的事实 —— 冷却进度、三问答成什么样、占清单多少；
/// 4. 加入日期 —— 判断「我是不是已经想它很久了」。
///
/// 点整行打开详情（看三问原文、写过的备注、做决定）；右侧 ⋯ 只放编辑/删除。
class _WishlistRow extends StatelessWidget {
  const _WishlistRow({
    required this.entry,
    required this.profile,
    required this.now,
    required this.shareDays,
    required this.totalDays,
    required this.insight,
    required this.onOpen,
    required this.onEdit,
    required this.onSettle,
    required this.onDelete,
  });

  final WishlistEntry entry;
  final WorkProfile? profile;
  final DateTime now;
  final double? shareDays;
  final double totalDays;
  final WishlistInsight? insight;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final ValueChanged<WishlistItemStatus> onSettle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;
    final masked = MoneyPrivacy.of(context);
    final status = entry.statusAt(now);
    final settled = status.isSettled;
    final days = profile == null ? null : entry.daysFor(profile!);
    final hours = profile == null ? null : entry.hoursFor(profile!);
    final currency = profile?.currencyCode ?? 'CNY';

    return AppSurface(
      padding: EdgeInsets.all(spacing.cardPadding),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DesireBadge(desire: entry.desire, dimmed: settled),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: settled
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              WishlistStatusChip(status: status, entry: entry, now: now),
              PopupMenuButton<String>(
                tooltip: '更多',
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'bought') {
                    onSettle(WishlistItemStatus.bought);
                  } else if (value == 'dropped') {
                    onSettle(WishlistItemStatus.dropped);
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined, size: 18),
                      title: Text('编辑'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'bought',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.shopping_bag_outlined, size: 18),
                      title: Text('买了'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'dropped',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.close_rounded, size: 18),
                      title: Text('放弃'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline_rounded, size: 18),
                      title: Text('删除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (days != null)
                Text(
                  masked ? '••••' : '${formatLifeEnergyWorkdays(days)} 工作日',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: settled
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    letterSpacing: 0,
                  ),
                )
              else
                Text(
                  '填完收入与工时后显示天数',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              if (hours != null && !masked) ...[
                const SizedBox(width: 6),
                Text(
                  '≈ ${formatLifeEnergyHours(hours)} 小时',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
          if (status == WishlistItemStatus.waiting) ...[
            const SizedBox(height: 8),
            _CooldownBar(entry: entry, now: now),
          ],
          const SizedBox(height: 8),
          // 用 Wrap 不用 Row：390 宽上「三问 · 占清单 · 加入日期」三截挤一行会
          // 溢出（长标题 + 中文数字时尤其明显），换行比截断好看。
          Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AnswerDots(answers: entry.questionAnswers),
                  const SizedBox(width: 4),
                  Text(
                    '三问 ${entry.answeredQuestionCount}/3',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              Text(
                masked
                    ? '••••'
                    : formatMoneyMinor(entry.targetAmountMinor, currency),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              if (!settled && shareDays != null && totalDays > 0)
                Text(
                  '占清单 ${_sharePercent(shareDays!, totalDays)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              Text(
                '${entry.createdAt.month} 月 ${entry.createdAt.day} 日加入',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 「想要 / 很想要 / 没它不行」。三档用深浅区分，不用颜色 —— 清单里颜色已经
/// 被状态占用了，再来一套配色就成了红绿灯。
class _DesireBadge extends StatelessWidget {
  const _DesireBadge({required this.desire, required this.dimmed});

  final WishDesireLevel desire;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filled = switch (desire) {
      WishDesireLevel.want => 1,
      WishDesireLevel.strong => 2,
      WishDesireLevel.need => 3,
    };
    final fg = dimmed ? colorScheme.onSurfaceVariant : colorScheme.onSurface;

    return Tooltip(
      message: desire.label,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 3,
                height: i < filled ? 10 : 4,
                margin: const EdgeInsets.symmetric(horizontal: 0.5),
                decoration: BoxDecoration(
                  color: i < filled ? fg : colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 冷却进度：已经等了多少 / 还要等多久。
///
/// 只画进度不写百分比：百分比会被读成「决定完成度」，而这里只是时间。
class _CooldownBar extends StatelessWidget {
  const _CooldownBar({required this.entry, required this.now});

  final WishlistEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final money = theme.moneyColors;
    final deadline = entry.cooldownUntil;
    if (deadline == null) {
      return const SizedBox.shrink();
    }
    // 冷却总长按「加入 → 到期」算：用户设 7 天、第 5 天再编辑，进度条不会
    // 从 0 重跳，只是总长跟着拉长。
    final total = deadline.difference(entry.createdAt).inMinutes;
    final passed = now.difference(entry.createdAt).inMinutes;
    final ratio = total <= 0 ? 1.0 : (passed / total).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 4,
        backgroundColor: colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation(money.warningStrong),
      ),
    );
  }
}

/// 三个问题的小圆点：实心 = 是，空心 = 否，灰点 = 没答。
///
/// 用点不用文字：列表行里塞三段「是/否/没答」会读成一串符号，而这一栏只需
/// 回答「当初有没有认真想过」。
class _AnswerDots extends StatelessWidget {
  const _AnswerDots({required this.answers});

  final List<bool?> answers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final money = theme.moneyColors;
    return Row(
      children: [
        for (final answer in answers)
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: switch (answer) {
                true => money.incomeStrong,
                false => Colors.transparent,
                null => colorScheme.outlineVariant,
              },
              border: answer == false
                  ? Border.all(color: colorScheme.onSurfaceVariant, width: 1)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// 这件东西占整张清单的百分之几（四舍五入到整数，最低 1）。
int _sharePercent(double days, double totalDays) {
  if (totalDays <= 0) {
    return 0;
  }
  return (days / totalDays * 100).round().clamp(1, 100);
}
