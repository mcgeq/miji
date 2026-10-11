import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_auto_posting_conflict_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_auto_posting_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/auto_posting/money_auto_postings_section.dart';

void main() {
  testWidgets('merges the reminder banners into one collapsed row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        templates: [
          _template(id: 't-active', name: '房租'),
          _template(
            id: 't-taken',
            name: '车贷',
            isActive: false,
            takenOverByPlanId: 'plan-gone',
          ),
        ],
        plans: [_plan(id: 'plan-1', name: '招行信用卡分期')],
        conflicts: [_conflict()],
      ),
    );
    await tester.pumpAndSettle();

    // 回归：三层横幅（冲突 / 接管失效 / 分期预览）原来各自常驻展开，
    // 模板列表被挤到首屏之外。现在合并成一行，默认折叠。
    expect(find.text('需要处理 2 项'), findsOneWidget);
    expect(find.text('重复登记 · 接管失效'), findsOneWidget);
    expect(find.text('去处理'), findsNothing);
    expect(find.textContaining('同一笔还款会被记两遍账'), findsNothing);
    // 合并之后模板列表仍然看得到。
    expect(find.text('房租'), findsOneWidget);

    await tester.tap(find.text('需要处理 2 项'));
    await tester.pumpAndSettle();

    expect(find.textContaining('检测到 1 处重复登记'), findsOneWidget);
    expect(find.textContaining('接管的分期已结束'), findsOneWidget);
    expect(find.text('去处理'), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);
  });

  testWidgets('takes no space when there is nothing to handle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(templates: [_template(id: 't-1')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('需要处理'), findsNothing);
    expect(find.textContaining('个分期计划到期自动入账'), findsNothing);
  });

  testWidgets('sinks the installment preview into a one-line related link', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var opened = 0;
    await tester.pumpWidget(
      _wrap(
        templates: [_template(id: 't-1', name: '房租')],
        plans: [
          _plan(id: 'plan-1', name: '招行信用卡分期'),
          _plan(id: 'plan-2', name: '花呗分期'),
        ],
        onOpenInstallments: () => opened += 1,
      ),
    );
    await tester.pumpAndSettle();

    // 分期还款计划改由「分期」Tab 独占，这里只留一行入口（含数量）。
    expect(find.text('分期还款计划'), findsNothing);
    expect(find.text('2 个分期计划到期自动入账'), findsOneWidget);

    await tester.ensureVisible(find.text('2 个分期计划到期自动入账'));
    await tester.tap(find.text('2 个分期计划到期自动入账'));
    await tester.pumpAndSettle();

    expect(opened, 1);
  });
}

Widget _wrap({
  List<MoneyAutoPostingTemplateEntity> templates = const [],
  List<MoneyInstallmentPlanEntity> plans = const [],
  List<MoneyAutoPostingInstallmentConflict> conflicts = const [],
  VoidCallback? onOpenInstallments,
}) {
  final ledger = MoneyLedgerEntity(
    id: 'ledger-1',
    userId: 'user-1',
    name: '日常账本',
    ledgerType: 'personal',
    status: 'active',
    baseCurrencyCode: 'CNY',
    createdAt: _createdAt,
    updatedAt: _createdAt,
  );
  return ProviderScope(
    overrides: [
      currentUserCurrentLedgerValueProvider.overrideWithValue(ledger),
      currentUserMoneyLedgerAccountsProvider.overrideWith(
        (ref, ledgerId) => Stream.value([_account]),
      ),
      currentUserAutoPostingTemplatesProvider.overrideWith(
        (ref) => Stream.value(templates),
      ),
      currentUserAutoPostingRunsProvider.overrideWith(
        (ref, templateId) => Stream.value(const <MoneyAutoPostingRunEntity>[]),
      ),
      currentUserAutoPostingInstallmentConflictsProvider.overrideWith(
        (ref) async => conflicts,
      ),
      currentUserInstallmentPlansProvider.overrideWith(
        (ref) => Stream.value(plans),
      ),
      currentUserCategoryCatalogProvider.overrideWith(
        (ref, kind) => Stream.value(
          const MoneyCategoryCatalog(
            categories: [_category],
            subCategories: [],
          ),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MoneyAutoPostingsSection(onOpenInstallments: onOpenInstallments),
      ),
    ),
  );
}

final _createdAt = DateTime(2026, 1, 1);

MoneyAutoPostingTemplateEntity _template({
  required String id,
  String name = '房租',
  bool isActive = true,
  String? takenOverByPlanId,
}) {
  return MoneyAutoPostingTemplateEntity(
    id: id,
    userId: 'user-1',
    name: name,
    type: MoneyTransactionType.expense,
    amountMinor: 320000,
    currencyCode: 'CNY',
    description: '每月房租',
    notes: null,
    merchant: null,
    accountId: 'account-1',
    categoryId: 'expense_home',
    subCategoryId: null,
    paymentMethod: MoneyPaymentMethod.cash,
    customPaymentMethodName: null,
    actualPayerAccount: 'default',
    ledgerId: 'ledger-1',
    frequency: MoneyAutoPostingFrequency.monthly,
    dayOfMonth: 1,
    weekday: null,
    timeOfDayMinutes: 8 * 60,
    startsOn: DateTime(2026, 1, 1),
    endsOn: null,
    isActive: isActive,
    version: 1,
    isDeleted: false,
    createdAt: _createdAt,
    updatedAt: _createdAt,
    takenOverByPlanId: takenOverByPlanId,
  );
}

MoneyInstallmentPlanEntity _plan({required String id, required String name}) {
  return MoneyInstallmentPlanEntity(
    id: id,
    userId: 'user-1',
    ledgerId: 'ledger-1',
    accountId: 'account-1',
    name: name,
    totalPrincipalMinor: 499200,
    totalInterestMinor: 0,
    totalPeriods: 12,
    remainingPeriods: 9,
    periodAmountMinor: 41600,
    currencyCode: 'CNY',
    categoryId: 'expense_digital',
    startDate: DateTime(2026, 7, 1),
    endDate: DateTime(2027, 6, 1),
    firstDueDate: DateTime(2026, 10, 18),
    status: MoneyInstallmentPlanStatus.active,
    createdAt: _createdAt,
    updatedAt: _createdAt,
  );
}

MoneyAutoPostingInstallmentConflict _conflict() {
  return MoneyAutoPostingInstallmentConflict(
    ledgerId: 'ledger-1',
    templateId: 't-active',
    templateName: '房租',
    templateAmountMinor: 320000,
    currencyCode: 'CNY',
    planId: 'plan-1',
    planName: '招行信用卡分期',
    periodNumber: 3,
    dueDate: DateTime(2026, 10, 18),
    detailAmountMinor: 320000,
    kind: MoneyAutoPostingConflictKind.exactAmount,
    isTakenOver: false,
  );
}

final _account = MoneyAccountEntity(
  id: 'account-1',
  userId: 'user-1',
  name: '招商银行储蓄卡',
  type: MoneyAccountType.saving,
  balanceMinor: 0,
  initialBalanceMinor: 0,
  creditLimitMinor: null,
  postedDebtMinor: 0,
  frozenCreditMinor: 0,
  statementDay: null,
  budgetCycleStartDay: 1,
  repaymentDay: null,
  autoRepaymentReminderEnabled: false,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _createdAt,
  updatedAt: _createdAt,
);

const _category = MoneyCategoryEntity(
  id: 'expense_home',
  userId: 'user-1',
  name: '居住',
  kind: MoneyCategoryKind.expense,
  color: '#4F7DD9',
  icon: 'home',
  isSystem: true,
);
