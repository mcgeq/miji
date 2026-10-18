import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/presentation/life_energy_profile_page.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';

/// 档案页的口径问题：个税累计预扣让每月到手不同，默认必须引导用户填全年。
/// 这三条用例钉住「默认年档」「切月档有提示」「一键 ×12」。
Future<void> _pumpProfilePage(
  WidgetTester tester, {
  WorkProfile? profile,
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
        // 币种来源；测试里不需要真实账本。
        currentUserCurrentLedgerValueProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const LifeEnergyProfilePage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('新档案默认按全年填，标签点明「全年到手」', (tester) async {
    await _pumpProfilePage(tester);

    expect(find.text('全年到手'), findsOneWidget);
    expect(find.text('每月到手'), findsNothing);
    // 四档都在，且「全年」排最前（分段按钮按枚举顺序渲染）。
    expect(find.text('全年'), findsOneWidget);
    expect(find.text('按月'), findsOneWidget);
    expect(find.text('按日'), findsOneWidget);
    expect(find.text('按时'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切到「按月」会提示会偏，并给一键换全年的入口', (tester) async {
    await _pumpProfilePage(tester);

    await tester.tap(find.text('按月'));
    await tester.pumpAndSettle();

    expect(find.text('每月到手'), findsOneWidget);
    expect(find.text('按月填会偏'), findsOneWidget);
    expect(find.text('换成全年（×12）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('一键换全年：金额 ×12、切回年档、吸底条回显月均', (tester) async {
    await _pumpProfilePage(tester);

    await tester.tap(find.text('按月'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('lifeEnergyPayAmount')),
      '12000',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('换成全年（×12）'));
    await tester.pumpAndSettle();

    // 12,000 × 12 = 144,000，并且已经回到年档。
    expect(find.text('144000.00'), findsOneWidget);
    expect(find.text('全年到手'), findsOneWidget);
    expect(find.text('按月填会偏'), findsNothing);
    // 填全年之后，用户需要的第一个确认就是「这等于每月 12,000」。
    expect(find.text('月均到手 ¥12,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('「这个数从哪拿」默认收起，点开给出去查的路径', (tester) async {
    await _pumpProfilePage(tester);

    expect(find.textContaining('收入纳税明细查询'), findsNothing);

    await tester.tap(find.text('这个数从哪拿'));
    await tester.pumpAndSettle();

    expect(find.textContaining('收入纳税明细查询'), findsOneWidget);
    expect(find.textContaining('工作不满一年'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切到税前推算：多出五险一金与专项附加两组，金额框改成税前', (tester) async {
    await _pumpProfilePage(tester);

    expect(find.text('五险一金 · 个人承担的部分'), findsNothing);

    await tester.tap(find.text('税前推算'));
    await tester.pumpAndSettle();

    expect(find.text('税前月薪'), findsOneWidget);
    expect(find.text('五险一金 · 个人承担的部分'), findsOneWidget);
    expect(find.text('专项附加扣除 · 减的是计税基数'), findsOneWidget);
    // 到手明细的入口只在这一页出现，而且放在最底部（390 屏要滚到底才看得到）。
    await tester.scrollUntilVisible(
      find.text('看看是怎么算的'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('看看是怎么算的'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('税前模式下改金额，吸底条当场给出当月到手和时薪', (tester) async {
    await _pumpProfilePage(
      tester,
      profile: WorkProfile(
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
      ),
    );

    // 10 月（测试时钟默认当月）到手 14,650，时薪 60.6。
    expect(find.textContaining('10 月到手'), findsOneWidget);
    expect(find.textContaining('时薪 ¥60.6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 回归：填写税前月薪后，预览与保存校验都曾读一个「切口径时才更新」的副本，
  // 于是填了数却看到 0，按保存还被告知「先填税前月薪」。
  testWidgets('刚切到税前推算、金额框还空着：填完税前，吸底条当场给出到手', (tester) async {
    await _pumpProfilePage(
      tester,
      profile: WorkProfile(
        userId: 'user-1',
        payAmountMinor: 0,
        payCycle: LifeEnergyPayCycle.month,
        compensationMode: LifeEnergyCompensationMode.gross,
        // 关键：档案里还没存过税前（0），但用户在框里填了 20,000。
        grossMonthlyMinor: 0,
        payroll: SocialInsuranceConfig.defaults.copyWith(
          specialDeductionMinor: 200000,
        ),
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
        commuteMinutesPerDay: 70,
        overtimeMinutesPerMonth: 720,
        costTransportMinor: 170000,
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('lifeEnergyPayAmount')),
      '20000',
    );
    await tester.pumpAndSettle();

    // 与「已存过税前」的那条用例同一组数：10 月到手 14,650、时薪 ¥60.6。
    // 断言具体数字，不是「有个非零」—— 读坏副本时这里拿到的是 ¥0。
    expect(find.textContaining('10 月到手 · 时薪 ¥60.6'), findsOneWidget);
    expect(find.text('¥14,650'), findsOneWidget);
    expect(find.textContaining('这个月到手 ¥14,650'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切到另一个口径再切回来，刚填的金额不丢', (tester) async {
    await _pumpProfilePage(tester);

    await tester.tap(find.text('税前推算'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('lifeEnergyPayAmount')),
      '20000',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('直接填到手'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('税前推算'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('lifeEnergyPayAmount')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '20000.00');
    expect(tester.takeException(), isNull);
  });
}
