import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_summary_entity.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/life_energy_prefs.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/presentation/life_energy_section.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';

/// 面板要在 390 宽的窄屏上成立：Hero 的大字号、本月卡的长数字、本期卡的四行
/// 明细都挤在一列里，溢出只会出现在这个尺寸上。
Future<void> _pumpSection(
  WidgetTester tester, {
  WorkProfile? profile,
  List<WishlistEntry> wishlist = const <WishlistEntry>[],
  LifeEnergyPrefs prefs = LifeEnergyPrefs.empty,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentWorkProfileProvider.overrideWith(
          (ref) => AsyncData<WorkProfile?>(profile),
        ),
        currentWishlistProvider.overrideWith(
          (ref) => Stream<List<WishlistEntry>>.value(wishlist),
        ),
        currentMonthOvertimeProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        lifeEnergyPrefsProvider.overrideWithValue(prefs),
        currentMonthMoneySummaryProvider.overrideWith(
          (ref) async => const MoneyTransactionSummary(
            count: 12,
            expenseMinor: 842000,
            incomeMinor: 1200000,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: LifeEnergySection()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('没填档案时只给引导，不显示任何换算数字', (tester) async {
    await _pumpSection(tester);

    expect(find.text('先算出你的真实时薪'), findsOneWidget);
    expect(find.text('填写收入与工时'), findsOneWidget);
    // 空态不是「0 小时」：给假数字比空着更伤人。
    expect(find.textContaining('小时 ·'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('配好档案后显示真实时薪与本月支出，不再显示换算卡', (tester) async {
    await _pumpSection(
      tester,
      profile: const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
        commuteMinutesPerDay: 70,
        overtimeMinutesPerMonth: 720,
        costTransportMinor: 170000,
      ),
    );

    // 真实时薪 ¥48.2（12,000 − 1,700 除以 213.7 小时）。
    expect(find.text('¥48.2'), findsOneWidget);
    expect(find.textContaining('9.71 小时'), findsWidgets);
    // 本月花掉就是钱：8,420（测试里 12 笔流水）。不再折成小时/工作日。
    expect(find.text('¥8,420.00'), findsOneWidget);
    expect(find.text('12 笔支出'), findsOneWidget);
    expect(find.textContaining('174.7 小时'), findsNothing);
    expect(find.textContaining('18.0 个工作日'), findsNothing);

    // 开销必须看得见：真实时薪是「加通勤 + 减开销」两次调整后的结果，
    // 只给结果、不给两个调整，用户没法核对那六项估算值填对没有。
    expect(find.textContaining('名义 ¥68.2'), findsOneWidget);
    expect(find.textContaining('含通勤 ¥56.2'), findsOneWidget);
    expect(find.textContaining('扣开销后 ¥48.2'), findsOneWidget);
    expect(find.textContaining('工作开销 ¥1,700 / 月'), findsOneWidget);
    expect(find.textContaining('通勤 25.7 小时 / 月'), findsOneWidget);

    // 换算卡已删：面板不该再有一个「输一个金额看值几小时」的输入框。
    // 换算发生在想买清单里（加一件就看到天数），这里是回顾，不是试算。
    expect(find.byType(AppAmountField), findsNothing);
    expect(find.textContaining('先填收入与工时'), findsNothing);
    // 面板分两段，默认停在「换算」。
    expect(find.text('换算'), findsOneWidget);
    expect(find.text('想买'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('「想买」段就是完整清单：点得开详情，也能编辑和删除', (tester) async {
    await _pumpSection(
      tester,
      profile: const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
        commuteMinutesPerDay: 70,
        overtimeMinutesPerMonth: 720,
        costTransportMinor: 170000,
      ),
      wishlist: [
        WishlistEntry(
          id: 'a',
          userId: 'user-1',
          title: '降噪耳机',
          targetAmountMinor: 129900,
          storedStatus: WishlistItemStatus.ready,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    );

    await tester.tap(find.text('想买'));
    await tester.pumpAndSettle();

    // 想买段不再有面板标题与那句说明：切过来就是清单本身。
    expect(find.text('时薪'), findsNothing);
    expect(find.textContaining('先记下来，冷却几天再决定'), findsNothing);

    // 汇总卡：两列（钱 / 天数）+ 分段条图例 + 分组 + 那一件。
    expect(find.text('清单上的代价'), findsOneWidget);
    expect(find.text('个工作日'), findsOneWidget);
    expect(find.textContaining('可以决定 1 件'), findsOneWidget);
    expect(find.textContaining('按 10 月 ¥48.2 / 小时'), findsOneWidget);
    expect(find.text('可以决定 · 1 件'), findsOneWidget);
    expect(find.text('降噪耳机'), findsOneWidget);
    expect(find.text('2.8 工作日'), findsOneWidget);

    // ⋯ 菜单里编辑和删除都得在 —— 这是之前缺失的那条路。
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('买了'), findsOneWidget);
    expect(find.text('放弃'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.text('编辑想买的东西'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('面板里点整行打开详情，详情里有买了 / 放弃', (tester) async {
    await _pumpSection(
      tester,
      profile: const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
        commuteMinutesPerDay: 70,
        overtimeMinutesPerMonth: 720,
        costTransportMinor: 170000,
      ),
      wishlist: [
        WishlistEntry(
          id: 'a',
          userId: 'user-1',
          title: '降噪耳机',
          targetAmountMinor: 129900,
          storedStatus: WishlistItemStatus.ready,
          q1Satisfaction: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    );

    await tester.tap(find.text('想买'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('降噪耳机'));
    await tester.pumpAndSettle();

    expect(find.text('三个问题'), findsOneWidget);
    expect(find.text('买了'), findsWidgets);
    expect(find.text('放弃'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('上次停在「想买」，再打开面板就在想买段', (tester) async {
    await _pumpSection(
      tester,
      profile: const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
        commuteMinutesPerDay: 70,
        overtimeMinutesPerMonth: 720,
        costTransportMinor: 170000,
      ),
      wishlist: [
        WishlistEntry(
          id: 'a',
          userId: 'user-1',
          title: '降噪耳机',
          targetAmountMinor: 129900,
          storedStatus: WishlistItemStatus.ready,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
      prefs: const LifeEnergyPrefs(tab: 'wishlist'),
    );

    // 换算段的内容不该出现，想买段的清单在。
    expect(find.text('真实时薪'), findsNothing);
    expect(find.text('清单上的代价'), findsOneWidget);
    expect(find.text('降噪耳机'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
