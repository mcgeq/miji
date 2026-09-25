import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/application/money_export_service.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

void main() {
  MoneyTransactionEntity transaction({
    String? merchant,
    String? notes,
    List<String> tags = const [],
  }) {
    return MoneyTransactionEntity(
      id: 't1',
      userId: 'u1',
      type: MoneyTransactionType.expense,
      status: MoneyTransactionStatus.completed,
      transactionAt: DateTime(2026, 1, 5, 14, 30),
      amountMinor: 12345,
      refundAmountMinor: 0,
      currencyCode: 'CNY',
      description: '午餐',
      notes: notes,
      merchant: merchant,
      location: null,
      accountId: 'a1',
      toAccountId: null,
      categoryId: 'c1',
      subCategoryId: null,
      paymentMethod: MoneyPaymentMethod.wechatPay,
      customPaymentMethodName: null,
      actualPayerAccount: 'default',
      relatedTransactionId: null,
      installmentPlanId: null,
      sourceTemplateRunId: null,
      interestRateBasisPoints: null,
      totalInterestMinor: 0,
      calcMethod: null,
      tags: tags,
      isDeleted: false,
      createdAt: DateTime(2026, 1, 5),
      updatedAt: DateTime(2026, 1, 5),
    );
  }

  test('包含 BOM、表头与格式化金额', () {
    final csv = buildTransactionsCsv(
      transactions: [transaction()],
      accountNames: const {'a1': '微信'},
      categoryNames: const {'c1': '餐饮'},
    );

    expect(csv.startsWith('\uFEFF'), isTrue);
    expect(csv.split('\n').first, contains('时间,类型,金额'));
    expect(csv, contains('123.45'));
    expect(csv, contains('微信'));
    expect(csv, contains('餐饮'));
    expect(csv, contains('2026-01-05 14:30'));
    expect(csv, contains('已完成'));
  });

  test('逗号与引号被正确转义', () {
    final csv = buildTransactionsCsv(
      transactions: [
        transaction(merchant: 'A,B 超市', notes: '带"引号"的备注', tags: ['旅游', '报销']),
      ],
    );

    expect(csv, contains('"A,B 超市"'));
    expect(csv, contains('"带""引号""的备注"'));
    expect(csv, contains('旅游、报销'));
  });

  test('空列表只输出表头', () {
    final csv = buildTransactionsCsv(transactions: const []);
    expect(csv.trim().split('\n').length, 1);
  });
}
