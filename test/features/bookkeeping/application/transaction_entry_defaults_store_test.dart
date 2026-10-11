import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/application/transaction_entry_defaults_store.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('stores defaults separately by ledger and transaction type', () async {
    const store = TransactionEntryDefaultsStore();

    await store.saveDefaults(
      userId: 'user-1',
      ledgerId: 'ledger-a',
      type: MoneyTransactionType.expense,
      defaults: const TransactionEntryDefaults(
        accountId: 'cash',
        categoryId: 'food',
        subCategoryId: 'breakfast',
        paymentMethod: MoneyPaymentMethod.cash,
      ),
    );

    expect(
      await store.readDefaults(
        userId: 'user-1',
        ledgerId: 'ledger-a',
        type: MoneyTransactionType.expense,
      ),
      const TransactionEntryDefaults(
        accountId: 'cash',
        categoryId: 'food',
        subCategoryId: 'breakfast',
        paymentMethod: MoneyPaymentMethod.cash,
      ),
    );

    expect(
      await store.readDefaults(
        userId: 'user-1',
        ledgerId: 'ledger-a',
        type: MoneyTransactionType.income,
      ),
      isNull,
    );
  });

  test('stores subcategory memory separately per category', () async {
    const store = TransactionEntryDefaultsStore();

    await store.saveSubCategoryForCategory(
      userId: 'user-1',
      ledgerId: 'ledger-a',
      type: MoneyTransactionType.expense,
      categoryId: 'food',
      subCategoryId: 'lunch',
    );

    expect(
      await store.readSubCategoryForCategory(
        userId: 'user-1',
        ledgerId: 'ledger-a',
        type: MoneyTransactionType.expense,
        categoryId: 'food',
      ),
      'lunch',
    );

    expect(
      await store.readSubCategoryForCategory(
        userId: 'user-1',
        ledgerId: 'ledger-a',
        type: MoneyTransactionType.expense,
        categoryId: 'transport',
      ),
      isNull,
    );
  });
}
