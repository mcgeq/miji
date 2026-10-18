import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/salary_history.dart';
import 'package:miji/features/life_energy/domain/salary_segment.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/presentation/life_energy_salary_history_page.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';

/// 390 宽是这一页的压力点：公司名 + 两个 chip + 时薪 + 菜单全挤在一行。
Future<void> _pumpPage(WidgetTester tester, SalaryHistory history) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        salaryHistoryProvider.overrideWith((ref) => history),
        lifeEnergyClockProvider.overrideWithValue(() => DateTime(2026, 10, 18)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const LifeEnergySalaryHistoryPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _profile = WorkProfile(
  userId: 'user-1',
  payAmountMinor: 1200000,
  payCycle: LifeEnergyPayCycle.month,
  workDaysPerMonth: 22,
  workMinutesPerDay: 480,
  commuteMinutesPerDay: 70,
  overtimeMinutesPerMonth: 720,
  costTransportMinor: 170000,
);

SalarySegment _segment({
  required String id,
  required int year,
  required int month,
  required int amountMinor,
  String? employer,
  int? commute,
  int? workCost,
}) {
  return SalarySegment(
    id: id,
    userId: 'user-1',
    employer: employer,
    effectiveYear: year,
    effectiveMonth: month,
    amountMinor: amountMinor,
    commuteMinutesPerDay: commute,
    workCostMonthlyMinor: workCost,
    createdAt: DateTime(year, month),
    updatedAt: DateTime(year, month),
  );
}

void main() {
  testWidgets('三段：公司名、当前 / 跳槽标记、各段自己的时薪都在', (tester) async {
    final history = SalaryHistory(
      profile: _profile,
      segments: [
        _segment(
          id: 'a',
          year: 2024,
          month: 1,
          amountMinor: 1600000,
          employer: '星野科技',
          commute: 30,
          workCost: 120000,
        ),
        _segment(
          id: 'b',
          year: 2025,
          month: 1,
          amountMinor: 2000000,
          employer: '云图科技',
        ),
        _segment(
          id: 'c',
          year: 2026,
          month: 7,
          amountMinor: 2500000,
          employer: '云图科技',
        ),
      ],
    );
    await _pumpPage(tester, history);

    expect(find.text('星野科技'), findsOneWidget);
    expect(find.text('云图科技'), findsNWidgets(2));
    expect(find.text('当前'), findsOneWidget);
    expect(find.text('跳槽'), findsOneWidget);
    // 旧段的时薪按它自己那段算（16,000 − 1,200，199 小时 → 74.4）
    expect(find.textContaining('¥74.4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('只有一段时给提示，不显示涨幅', (tester) async {
    final history = SalaryHistory(
      profile: _profile,
      segments: [
        _segment(
          id: 'a',
          year: 2026,
          month: 7,
          amountMinor: 2500000,
          employer: '云图科技',
        ),
      ],
    );
    await _pumpPage(tester, history);

    expect(find.textContaining('只有一段时看不出'), findsOneWidget);
    expect(find.textContaining('% 时薪'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('没填工作单位时用兜底文案，不显示空白行', (tester) async {
    final history = SalaryHistory(
      profile: _profile,
      segments: [
        _segment(id: 'a', year: 2025, month: 1, amountMinor: 2000000),
        _segment(id: 'b', year: 2026, month: 7, amountMinor: 2500000),
      ],
    );
    await _pumpPage(tester, history);

    expect(find.text('未填写工作单位'), findsNWidgets(2));
    // 两段都没公司名 → 不当成跳槽
    expect(find.text('跳槽'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
