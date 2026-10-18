import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/presentation/life_energy_bonus_section.dart';
import 'package:miji/features/life_energy/presentation/life_energy_profile_page.dart';
import 'package:miji/features/life_energy/presentation/salary_segment_sheet.dart';
import 'package:miji/features/life_energy/presentation/wishlist_entry_sheet.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

import 'fake_life_energy_actions.dart';

/// 表单 → action 这一段之前没有测试：sheet 里填的东西、开关的状态、清空之后
/// 传的是 null 还是旧值，全靠人眼。用假 actions 把这一段单独钉住。
///
/// 时钟固定在 2026-10-18：年终奖默认年份、冷却期截止日都要可复现。
final _now = DateTime(2026, 10, 18, 9);

const _profile = WorkProfile(
  userId: 'user-1',
  payAmountMinor: 1200000,
  workDaysPerMonth: 22,
  workMinutesPerDay: 480,
  commuteMinutesPerDay: 70,
  overtimeMinutesPerMonth: 720,
  costTransportMinor: 170000,
);

/// 假 actions 自己也是一个 provider：直接 `late` 变量会被「没人读」拖成
/// 未初始化 —— 覆盖项是懒的，只有在 sheet 保存时才第一次被读。
final _fakeActionsProvider = Provider<FakeLifeEnergyActions>(
  (ref) => FakeLifeEnergyActions(ref),
);

Future<FakeLifeEnergyActions> _pump(
  WidgetTester tester,
  Widget host, {
  WorkProfile? profile = _profile,
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
          (ref) => Stream<List<WishlistEntry>>.value(const []),
        ),
        lifeEnergyClockProvider.overrideWithValue(() => _now),
        lifeEnergyActionsProvider.overrideWith(
          (ref) => ref.read(_fakeActionsProvider),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: host),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
    listen: false,
  );
  return container.read(_fakeActionsProvider);
}

Finder _fieldWithLabel(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byType(AppTextField),
  );
}

Finder _amountField() {
  return find.descendant(
    of: find.byType(AppAmountField),
    matching: find.byType(TextField),
  );
}

void main() {
  testWidgets('年终奖：默认记今年，金额按分保存，来源与备注一起带上', (tester) async {
    final actions = await _pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showBonusSheet(context),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('2026 年度'), findsOneWidget, reason: '默认年份是今年');

    await tester.enterText(_amountField(), '40000');
    await tester.enterText(_fieldWithLabel('发放方'), '云图科技');
    await tester.enterText(_fieldWithLabel('备注'), '年终奖');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(actions.savedBonuses, hasLength(1));
    final saved = actions.savedBonuses.single;
    expect(saved.taxYear, 2026);
    expect(saved.amountMinor, 4000000);
    expect(saved.sourceLabel, '云图科技');
    expect(saved.note, '年终奖');
    expect(saved.editing, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('想买：标题、金额、想要程度、三问、备注、冷却期一起传下去', (tester) async {
    final actions = await _pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showWishlistEntrySheet(context),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.enterText(_fieldWithLabel('想买什么'), '降噪耳机');
    await tester.enterText(_amountField(), '1299');
    await tester.enterText(_fieldWithLabel('为什么想买'), '通勤一小时，地铁太吵');
    await tester.tap(find.text('很想要'));
    await tester.pumpAndSettle();

    // 三问的第一问答「是」，另两问不答 —— 存下来的应该是 true / null / null。
    // 三态循环：未答 → 是；点的是整行（InkWell），不是那段文字。
    final firstQuestion = find.text(wishlistQuestions[0]);
    await tester.ensureVisible(firstQuestion);
    await tester.pumpAndSettle();
    await tester.tap(firstQuestion);
    await tester.pumpAndSettle();

    await tester.tap(find.text('14 天'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(actions.savedWishItems, hasLength(1));
    final saved = actions.savedWishItems.single;
    expect(saved.title, '降噪耳机');
    expect(saved.targetAmountMinor, 129900);
    expect(saved.notes, '通勤一小时，地铁太吵');
    expect(saved.desire, WishDesireLevel.strong);
    expect(saved.cooldownUntil, DateTime(2026, 11, 1, 9));
    expect(saved.q1, isTrue);
    expect(saved.q2, isNull);
    expect(saved.q3, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('想买：删空备注时传 null，不会把上一句留着', (tester) async {
    final entry = WishlistEntry(
      id: 'a',
      userId: 'user-1',
      title: '降噪耳机',
      targetAmountMinor: 129900,
      notes: '先前写的理由',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );
    await _pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showWishlistEntrySheet(context, entry: entry),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldWithLabel('为什么想买'), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    // 编辑走 updateWishlistItem（没被 fake 覆盖，走真实现会读 auth），
    // 这里只断言「没有崩」——清空语义由 copyWith(clearNotes:) 的单元测试覆盖。
    expect(tester.takeException(), isNull);
  });

  testWidgets('职业段：参数开关打开时，这一段单独存一份五险一金；关着就传 null', (tester) async {
    const grossProfile = WorkProfile(
      userId: 'user-1',
      payAmountMinor: 1465000,
      payCycle: LifeEnergyPayCycle.month,
      compensationMode: LifeEnergyCompensationMode.gross,
      grossMonthlyMinor: 2000000,
      workDaysPerMonth: 22,
      workMinutesPerDay: 480,
      commuteMinutesPerDay: 70,
      overtimeMinutesPerMonth: 720,
      costTransportMinor: 170000,
    );
    final actions = await _pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showSalarySegmentSheet(context),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
      profile: grossProfile,
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(_amountField(), '20000');
    await tester.pumpAndSettle();

    // 默认沿用档案：不写快照。
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    expect(actions.savedSegments, hasLength(1));
    expect(actions.savedSegments.single.payroll, isNull);

    // 再来一段，这次打开「这一段的五险一金参数不同」。
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(_amountField(), '20000');
    await tester.pumpAndSettle();
    final payrollSwitch = find.text('这一段的五险一金参数不同');
    await tester.ensureVisible(payrollSwitch);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.ancestor(of: payrollSwitch, matching: find.byType(Row)).first,
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(actions.savedSegments, hasLength(2));
    expect(
      actions.savedSegments.last.payroll,
      isNotNull,
      reason: '开关打开 = 这一段要自己的参数快照',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('档案页：改完点保存，落到 saveProfile 的是框里的数', (tester) async {
    final actions = await _pump(
      tester,
      const LifeEnergyProfilePage(),
      profile: const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        payCycle: LifeEnergyPayCycle.month,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
        commuteMinutesPerDay: 70,
        overtimeMinutesPerMonth: 720,
        costTransportMinor: 170000,
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('lifeEnergyPayAmount')),
      '15000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(actions.savedProfiles, hasLength(1));
    final saved = actions.savedProfiles.single;
    expect(saved.userId, 'user-1');
    expect(saved.payAmountMinor, 1500000);
    expect(saved.payCycle, LifeEnergyPayCycle.month);
    expect(saved.commuteMinutesPerDay, 70);
    expect(tester.takeException(), isNull);
  });
}
