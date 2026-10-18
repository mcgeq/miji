import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_page.dart';

/// 单笔流水页存在的理由：调用方只有 id。所以这一组用例把「id → 页面」这条路
/// 走一遍，包括「这笔已经不在」与「读取失败」两种不同的状态。
void main() {
  MoneyTransactionEntity transaction({String id = 'txn-1'}) {
    final at = DateTime.utc(2026, 10, 18, 12, 10);
    return MoneyTransactionEntity(
      id: id,
      userId: 'user-1',
      type: MoneyTransactionType.expense,
      status: MoneyTransactionStatus.completed,
      transactionAt: at,
      amountMinor: 3800,
      refundAmountMinor: 0,
      currencyCode: 'CNY',
      description: '午餐',
      notes: null,
      merchant: null,
      location: null,
      accountId: 'acc-1',
      toAccountId: null,
      categoryId: 'cat-1',
      subCategoryId: null,
      paymentMethod: MoneyPaymentMethod.alipay,
      customPaymentMethodName: null,
      actualPayerAccount: 'self',
      relatedTransactionId: null,
      installmentPlanId: null,
      sourceTemplateRunId: null,
      interestRateBasisPoints: null,
      totalInterestMinor: 0,
      calcMethod: null,
      tags: const <String>[],
      isDeleted: false,
      createdAt: at,
      updatedAt: at,
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    required Future<MoneyTransactionEntity?> Function() read,
  }) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith(() => _Unlocked()),
          transactionByIdProvider.overrideWith((ref, id) => read()),
          // 详情内容会读账户与分类目录；不覆盖的话它们去连真库，
          // 骨架屏的动画会让 pumpAndSettle 一直等下去。
          currentUserVisibleAccountsProvider.overrideWith(
            (ref) => Stream.value(const <MoneyAccountEntity>[]),
          ),
          currentUserCategoryCatalogProvider.overrideWith(
            (ref, kind) => Stream.value(const MoneyCategoryCatalog.empty()),
          ),
          // 详情内容还会读账本 / 内部账户；不覆盖的话它们在 teardown 时
          // 仍处于 loading，会抛「disposed during loading」。
          currentUserMoneyLedgersProvider.overrideWith(
            (ref) => Stream.value(const <MoneyLedgerEntity>[]),
          ),
          currentUserEffectiveTransactionLedgerValueProvider.overrideWithValue(
            null,
          ),
          currentUserMoneyInternalAccountsProvider.overrideWith(
            (ref) => Stream.value(const <MoneyAccountEntity>[]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const TransactionDetailPage(transactionId: 'txn-1'),
        ),
      ),
    );
    // 不用 pumpAndSettle：详情页里可能有骨架屏 / 渐变动画在跑，settle 会一直等。
    // 这里只要「数据到位、渲染出来」，定帧即可。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('按 id 打开：渲染出这一笔的内容', (tester) async {
    await pump(tester, read: () async => transaction());
    expect(find.text('流水详情'), findsOneWidget);
    expect(find.text('午餐'), findsWidgets);
  });

  testWidgets('这笔已经不在了：直说，而不是一直转圈', (tester) async {
    await pump(tester, read: () async => null);
    expect(find.text('这笔流水已经不在了'), findsOneWidget);
  });

  testWidgets('读取失败：给重试入口', (tester) async {
    await pump(tester, read: () async => throw StateError('boom'));
    expect(find.text('读取失败 · 重试'), findsOneWidget);
  });
}

class _Unlocked extends AuthSessionController {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'user-1', isUnlocked: true, unlockedAt: null);
}
