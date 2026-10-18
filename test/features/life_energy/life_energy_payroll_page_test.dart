import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/salary_history.dart';
import 'package:miji/features/life_energy/domain/salary_segment.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/presentation/life_energy_payroll_page.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';

/// 设计稿场景 09：税前 2 万 · 北京 · 专项扣除 2,000 那一份年度账。
WorkProfile _profile() => WorkProfile(
  userId: 'user-1',
  payAmountMinor: 1465000,
  payCycle: LifeEnergyPayCycle.month,
  compensationMode: LifeEnergyCompensationMode.gross,
  grossMonthlyMinor: 2000000,
  payroll: SocialInsuranceConfig.defaults.copyWith(
    specialDeductionMinor: 200000,
  ),
  workDaysPerMonth: 22,
  workMinutesPerDay: 480,
  commuteMinutesPerDay: 70,
  overtimeMinutesPerMonth: 720,
  costTransportMinor: 170000,
);

AnnualPayroll _plan() => PayrollCalculator(config: _profile().payroll).annual(
  year: 2026,
  inputs: List.generate(12, (_) => PayrollMonthInput.gross(2000000)),
);

Future<void> _pumpPayrollPage(
  WidgetTester tester, {
  AnnualPayroll? plan,
  WorkProfile? profile,
  SalaryHistory? history,
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // 页面按年份取计划（往年也能看），所以覆盖的是 family 本身。
        annualPayrollProvider.overrideWith((ref, year) => plan),
        if (history != null)
          salaryHistoryProvider.overrideWith((ref) => history),
        currentWorkProfileProvider.overrideWith(
          (ref) => AsyncData<WorkProfile?>(profile),
        ),
        currentUserCurrentLedgerValueProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const LifeEnergyPayrollPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('全年到手 178,320 · 占应发 74.3%', (tester) async {
    await _pumpPayrollPage(tester, plan: _plan(), profile: _profile());

    expect(find.text('全年到手'), findsOneWidget);
    expect(find.text('¥178,320'), findsWidgets);
    expect(find.text('74.3%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('一年的账：应发、五险一金、个税、公积金、公司另付', (tester) async {
    await _pumpPayrollPage(tester, plan: _plan(), profile: _profile());

    expect(find.text('年应发'), findsOneWidget);
    expect(find.text('¥240,000'), findsWidgets);
    expect(find.text('五险一金（个人）'), findsOneWidget);
    expect(find.text('−¥54,000'), findsOneWidget);
    expect(find.text('个人所得税'), findsOneWidget);
    expect(find.text('−¥7,680'), findsOneWidget);
    // 公积金单列：它是支出，但不是消耗。
    expect(find.textContaining('公积金（个人 + 单位）'), findsOneWidget);
    expect(find.text('¥57,600'), findsOneWidget);
    expect(find.text('公司另付'), findsOneWidget);
    expect(find.text('¥92,160'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('柱子画的是个税，档位变化写在柱子下面', (tester) async {
    await _pumpPayrollPage(tester, plan: _plan(), profile: _profile());

    expect(find.textContaining('3% 档 · 4 个月 → 10% 档 · 8 个月'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('用的是「直接填到手」时，这一页没有内容可展示', (tester) async {
    await _pumpPayrollPage(tester);

    expect(find.text('这一页要等填了税前才有'), findsOneWidget);
    // 不给「去切换模式」的按钮：把用户推到一个他没打算做的决定上。
    expect(find.text('全年到手'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('有往年数据时能切年份，切完看的是那一年的账', (tester) async {
    await _pumpPayrollPage(
      tester,
      plan: _plan(),
      profile: _profile(),
      history: SalaryHistory(
        profile: _profile(),
        segments: [
          SalarySegment(
            id: 'a',
            userId: 'user-1',
            effectiveYear: 2024,
            effectiveMonth: 1,
            amountMinor: 1465000,
            grossAmountMinor: 2000000,
            createdAt: DateTime(2024, 1),
            updatedAt: DateTime(2024, 1),
          ),
        ],
      ),
    );

    // 档案最早一段在 2024，所以 2025/2026 都能选。
    expect(find.textContaining('年'), findsWidgets);
    await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
    await tester.pumpAndSettle();
    expect(find.text('2025 年'), findsOneWidget);
    await tester.tap(find.text('2025 年'));
    await tester.pumpAndSettle();

    // 切完年份后 AppBar 上是 2025，年度账照常渲染。
    expect(find.text('2025 年'), findsOneWidget);
    expect(find.text('全年到手'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
