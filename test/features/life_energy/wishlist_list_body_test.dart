import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_commitment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_summary_entity.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/life_energy_prefs.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/presentation/wishlist_list_body.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';

/// 清单页的三件事：**分组**（今天能决定哪几件）、**每件的代价与来龙去脉**、
/// **详情摊开**。第三件是这轮重做的重点 —— 只给标题和天数，用户没法判断
/// 「我当初为什么想买它」。
///
/// 时钟固定在 2026-10-18：冷却天数、加入日期都要可复现。
final _now = DateTime(2026, 10, 18, 9);

/// 月到手 12,000 · 22 天 · 8 小时 · 通勤 70 分 · 加班 12h · 开销 1,700
/// → 真实时薪 ¥48.2，一个工作日 9.71 小时。
const _profile = WorkProfile(
  userId: 'user-1',
  payAmountMinor: 1200000,
  workDaysPerMonth: 22,
  workMinutesPerDay: 480,
  commuteMinutesPerDay: 70,
  overtimeMinutesPerMonth: 720,
  costTransportMinor: 170000,
);

WishlistEntry _entry({
  required String id,
  required String title,
  required int amountMinor,
  WishlistItemStatus status = WishlistItemStatus.ready,
  WishDesireLevel desire = WishDesireLevel.want,
  DateTime? cooldownUntil,
  bool? q1,
  bool? q2,
  bool? q3,
  String? notes,
  int createdDay = 1,
}) {
  return WishlistEntry(
    id: id,
    userId: 'user-1',
    title: title,
    targetAmountMinor: amountMinor,
    desire: desire,
    storedStatus: status,
    cooldownUntil: cooldownUntil,
    q1Satisfaction: q1,
    q2Aligned: q2,
    q3NoJob: q3,
    notes: notes,
    createdAt: DateTime(2026, 10, createdDay),
    updatedAt: DateTime(2026, 10, createdDay),
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required List<WishlistEntry> entries,
  WorkProfile? profile = _profile,
  int? spentMinor,
  List<MoneyBudgetCommitmentItem> committed = const [],
  List<MoneyBudgetCommitmentItem> nextMonth = const [],
  LifeEnergyPrefs prefs = LifeEnergyPrefs.empty,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentWorkProfileProvider.overrideWith(
          (ref) => AsyncData<WorkProfile?>(profile),
        ),
        currentWishlistProvider.overrideWith(
          (ref) => Stream<List<WishlistEntry>>.value(entries),
        ),
        lifeEnergyClockProvider.overrideWithValue(() => _now),
        lifeEnergyPrefsProvider.overrideWithValue(prefs),
        if (spentMinor != null)
          currentMonthMoneySummaryProvider.overrideWith(
            (ref) async => MoneyTransactionSummary(
              count: 9,
              expenseMinor: spentMinor,
              incomeMinor: 0,
            ),
          ),
        currentCommittedExpenseProvider.overrideWith(
          (ref) async => CommittedExpenseWindow(
            thisMonth: committed,
            nextMonth: nextMonth,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: WishlistListBody()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('分成「可以决定 / 冷却中 / 已结束」三组，已结束默认收起', (tester) async {
    await _pumpPage(
      tester,
      entries: [
        _entry(id: 'a', title: '降噪耳机', amountMinor: 129900),
        _entry(
          id: 'b',
          title: '人体工学椅',
          amountMinor: 300000,
          cooldownUntil: DateTime(2026, 10, 21, 9),
        ),
        _entry(
          id: 'c',
          title: '旧键盘',
          amountMinor: 50000,
          status: WishlistItemStatus.bought,
        ),
      ],
    );

    // 汇总条带口径：折算按月算，必须写清是哪个月的时薪。
    expect(find.text('清单上的代价'), findsOneWidget);
    expect(find.textContaining('按 10 月 ¥48.2 / 小时'), findsOneWidget);

    expect(find.text('可以决定 · 1 件'), findsOneWidget);
    expect(find.text('冷却中 · 1 件'), findsOneWidget);
    expect(find.text('已结束 · 1 件'), findsOneWidget);
    // 已结束的默认不展开，只给一个入口。
    expect(find.text('旧键盘'), findsNothing);
    expect(find.text('点开看 1 件已结束的'), findsOneWidget);

    await tester.tap(find.text('点开看 1 件已结束的'));
    await tester.pumpAndSettle();
    expect(find.text('旧键盘'), findsOneWidget);

    // 组是固定顺序：能决定的永远在最上面，跟排序方式无关。
    final readyY = tester.getTopLeft(find.text('可以决定 · 1 件')).dy;
    final waitingY = tester.getTopLeft(find.text('冷却中 · 1 件')).dy;
    expect(readyY, lessThan(waitingY));
    expect(tester.takeException(), isNull);
  });

  testWidgets('一件东西摊出四层信息：代价、想要程度、三问、占比、加入日期', (tester) async {
    await _pumpPage(
      tester,
      entries: [
        _entry(
          id: 'a',
          title: '降噪耳机',
          amountMinor: 129900,
          desire: WishDesireLevel.strong,
          q1: true,
          q2: false,
          createdDay: 3,
        ),
        _entry(id: 'b', title: '显示器', amountMinor: 300000),
      ],
    );

    // 代价：1,299 ÷ 48.2 ≈ 26.9 小时 ≈ 2.8 个工作日。
    expect(find.text('2.8 工作日'), findsOneWidget);
    expect(find.text('≈ 26.9 小时'), findsOneWidget);
    expect(find.text('¥1,299.00'), findsOneWidget);
    // 三问答了 2 个；清单合计 2.78 + 6.41 = 9.18 天，这件占 30%。
    expect(find.text('三问 2/3'), findsOneWidget);
    expect(find.textContaining('占清单 30%'), findsOneWidget);
    expect(find.text('10 月 3 日加入'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('冷却中的行给出进度条与「还要几天」，到期后换成「可以决定了」', (tester) async {
    await _pumpPage(
      tester,
      entries: [
        _entry(
          id: 'a',
          title: '人体工学椅',
          amountMinor: 300000,
          cooldownUntil: DateTime(2026, 10, 21, 9),
        ),
      ],
    );

    // 文案与设计稿一致：冷却中 · 还有 3 天 / 可以决定了。
    expect(find.text('冷却中 · 还有 3 天'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('可以决定了'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点开一件：三问原文、备注、时间线都在，决定按钮也在', (tester) async {
    await _pumpPage(
      tester,
      entries: [
        _entry(
          id: 'a',
          title: '降噪耳机',
          amountMinor: 129900,
          desire: WishDesireLevel.strong,
          q1: true,
          q2: false,
          notes: '通勤一小时，地铁太吵了',
          createdDay: 3,
        ),
      ],
    );

    await tester.tap(find.text('降噪耳机'));
    await tester.pumpAndSettle();

    // 三问原句 + 每个答案的状态。
    for (final question in wishlistQuestions) {
      expect(find.text(question), findsOneWidget);
    }
    expect(find.text('是'), findsOneWidget);
    expect(find.text('否'), findsOneWidget);
    expect(find.text('没答'), findsOneWidget);
    expect(find.text('通勤一小时，地铁太吵了'), findsOneWidget);
    expect(find.textContaining('2026 年 10 月 3 日加入'), findsOneWidget);
    // 详情里的天数是算出来的，也必须交代用的是哪个月的时薪。
    // 列表的汇总条也写了同一句（藏在「合计 · 按 …」里），所以用 containing。
    expect(find.textContaining('按 10 月 ¥48.2 / 小时'), findsNWidgets(2));
    expect(find.text('买了'), findsWidgets);
    expect(find.text('放弃'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('汇总卡说清「本月还能自由花」：到手 − 已花 − 还要付', (tester) async {
    await _pumpPage(
      tester,
      // 到手 12,000 · 已花 11,400 · 月度账单还没到期 300 → 余 300。
      spentMinor: 1140000,
      committed: [
        MoneyBudgetCommitmentItem(
          source: MoneyBudgetCommitmentSource.autoPosting,
          sourceId: 't1',
          title: '房贷',
          date: DateTime(2026, 10, 25),
          amountMinor: 20000,
          detail: '自动记账',
        ),
        MoneyBudgetCommitmentItem(
          source: MoneyBudgetCommitmentSource.installment,
          sourceId: 'i1',
          title: '车贷',
          date: DateTime(2026, 10, 28),
          amountMinor: 10000,
          detail: '第 3 期',
        ),
      ],
      nextMonth: [
        MoneyBudgetCommitmentItem(
          source: MoneyBudgetCommitmentSource.autoPosting,
          sourceId: 't1',
          title: '房贷',
          date: DateTime(2026, 11, 25),
          amountMinor: 800000,
          detail: '自动记账',
        ),
        MoneyBudgetCommitmentItem(
          source: MoneyBudgetCommitmentSource.installment,
          sourceId: 'i2',
          title: '车贷',
          date: DateTime(2026, 11, 28),
          amountMinor: 300000,
          detail: '第 4 期',
        ),
      ],
      entries: [_entry(id: 'a', title: '降噪耳机', amountMinor: 129900)],
    );

    expect(find.text('本月还能自由花'), findsOneWidget);
    expect(find.text('¥300.00'), findsOneWidget);
    // 明细要对得上：三个数都写出来，还能看到「还要付」是哪两笔。
    expect(find.textContaining('到手 ¥12,000.00'), findsOneWidget);
    expect(find.textContaining('已花 ¥11,400.00'), findsOneWidget);
    expect(find.textContaining('还要付 ¥300.00'), findsOneWidget);
    expect(find.textContaining('车贷 28 日'), findsNWidgets(2));
    // 清单合计 1,299 是余量 300 的 4.3 倍。
    expect(find.textContaining('4.3 倍'), findsOneWidget);
    // 下月固定支出单独一行：本月余量宽裕不代表下个月也宽裕。
    expect(find.textContaining('下月还要付 ¥11,000.00'), findsOneWidget);
    // 本月那行与下月那行都会提「房贷 25 日」（同一个模板的两个月）。
    expect(find.textContaining('房贷 25 日'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('余量已经是负的：直说这个月要动存款，不算倍数', (tester) async {
    await _pumpPage(
      tester,
      spentMinor: 1200000,
      committed: [
        MoneyBudgetCommitmentItem(
          source: MoneyBudgetCommitmentSource.billReminder,
          sourceId: 'b1',
          title: '信用卡账单',
          date: DateTime(2026, 10, 20),
          amountMinor: 50000,
        ),
      ],
      entries: [_entry(id: 'a', title: '降噪耳机', amountMinor: 129900)],
    );

    // 负号是 ASCII 连字符（NumberFormat 的输出），不是排版用的减号；
    // 明细行里的「还要付 ¥500.00」是正数，所以只有大数字带这个负号。
    expect(find.textContaining('-¥500.00'), findsOneWidget);
    expect(find.textContaining('买哪件都要动存款'), findsOneWidget);
    expect(find.textContaining('倍'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('排序沿用偏好里存的那一种，不用每次重新点', (tester) async {
    await _pumpPage(
      tester,
      prefs: const LifeEnergyPrefs(sort: 'cost'),
      entries: [
        _entry(id: 'a', title: '便宜的', amountMinor: 5000),
        _entry(id: 'b', title: '贵的', amountMinor: 500000),
      ],
    );

    expect(find.text('代价最高'), findsOneWidget, reason: '排序按钮显示的是存下来的那一种');
    final cheapY = tester.getTopLeft(find.text('便宜的')).dy;
    final expensiveY = tester.getTopLeft(find.text('贵的')).dy;
    expect(expensiveY, lessThan(cheapY));
    expect(tester.takeException(), isNull);
  });
}
