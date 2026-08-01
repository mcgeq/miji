import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

void main() {
  group('MoneyTransactionEntity.isInstallmentPosting', () {
    test('recognizes an installment transaction by its payer marker', () {
      final transaction = _transaction(
        actualPayerAccount: 'installment',
        installmentPlanId: null,
      );

      expect(transaction.isInstallmentPosting, isTrue);
    });

    test('recognizes an installment transaction by its plan id', () {
      final transaction = _transaction(
        actualPayerAccount: 'default',
        installmentPlanId: 'plan-1',
      );

      expect(transaction.isInstallmentPosting, isTrue);
    });

    test('keeps an ordinary transaction editable', () {
      final transaction = _transaction(
        actualPayerAccount: 'default',
        installmentPlanId: null,
      );

      expect(transaction.isInstallmentPosting, isFalse);
    });
  });
}

MoneyTransactionEntity _transaction({
  required String actualPayerAccount,
  required String? installmentPlanId,
}) {
  final now = DateTime.utc(2026, 7, 12);
  return MoneyTransactionEntity(
    id: 'transaction-1',
    userId: 'user-1',
    type: MoneyTransactionType.expense,
    status: MoneyTransactionStatus.completed,
    transactionAt: now,
    amountMinor: 10000,
    refundAmountMinor: 0,
    currencyCode: 'CNY',
    description: '分期入账',
    notes: null,
    merchant: null,
    location: null,
    accountId: 'account-1',
    toAccountId: null,
    categoryId: 'category-1',
    subCategoryId: null,
    paymentMethod: MoneyPaymentMethod.creditCard,
    customPaymentMethodName: null,
    actualPayerAccount: actualPayerAccount,
    relatedTransactionId: null,
    installmentPlanId: installmentPlanId,
    sourceTemplateRunId: null,
    interestRateBasisPoints: null,
    totalInterestMinor: 0,
    calcMethod: null,
    tags: const <String>[],
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  );
}
