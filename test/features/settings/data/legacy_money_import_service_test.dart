import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/settings/data/legacy_money_import_models.dart';
import 'package:miji/features/settings/data/legacy_money_import_service.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempDir;
  late AppDatabase appDatabase;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('miji_legacy_import_test_');
    appDatabase = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await appDatabase.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'previews importable table counts and skipped settlement tables',
    () async {
      final legacyPath =
          '${tempDir.path}${Platform.pathSeparator}legacy.sqlite';
      final legacyDb = sqlite3.open(legacyPath);
      try {
        legacyDb
          ..execute('CREATE TABLE account (serial_num TEXT PRIMARY KEY)')
          ..execute('CREATE TABLE transactions (serial_num TEXT PRIMARY KEY)')
          ..execute('CREATE TABLE debt_relations (serial_num TEXT PRIMARY KEY)')
          ..execute(
            'CREATE TABLE settlement_records (serial_num TEXT PRIMARY KEY)',
          )
          ..execute("INSERT INTO account (serial_num) VALUES ('acct_1')")
          ..execute("INSERT INTO transactions (serial_num) VALUES ('txn_1')")
          ..execute("INSERT INTO debt_relations (serial_num) VALUES ('debt_1')")
          ..execute(
            "INSERT INTO settlement_records (serial_num) VALUES ('set_1')",
          );
      } finally {
        legacyDb.close();
      }

      final service = LegacyMoneyImportService(database: appDatabase);
      final preview = await service.preview(legacyPath);

      expect(preview.canImport, isTrue);
      expect(preview.countFor('account'), 1);
      expect(preview.countFor('transactions'), 1);
      expect(
        preview.warnings.where(
          (warning) =>
              warning.severity == LegacyMoneyImportWarningSeverity.info &&
              warning.tableName == 'debt_relations',
        ),
        hasLength(1),
      );
      expect(
        preview.warnings.where(
          (warning) =>
              warning.severity == LegacyMoneyImportWarningSeverity.info &&
              warning.tableName == 'settlement_records',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'preview blocks import when no account or transaction table has data',
    () async {
      final legacyPath = '${tempDir.path}${Platform.pathSeparator}empty.sqlite';
      final legacyDb = sqlite3.open(legacyPath);
      try {
        legacyDb.execute('CREATE TABLE account (serial_num TEXT PRIMARY KEY)');
        legacyDb.execute(
          'CREATE TABLE transactions (serial_num TEXT PRIMARY KEY)',
        );
      } finally {
        legacyDb.close();
      }

      final service = LegacyMoneyImportService(database: appDatabase);
      final preview = await service.preview(legacyPath);

      expect(preview.canImport, isFalse);
      expect(preview.hasErrors, isTrue);
    },
  );

  test('imports core money data into personal and family ledgers', () async {
    final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
    await appDatabase
        .into(appDatabase.users)
        .insert(
          UsersCompanion.insert(
            id: 'user_1',
            username: 'user_1',
            email: 'user_1@example.com',
            displayName: '用户',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final legacyPath = '${tempDir.path}${Platform.pathSeparator}core.sqlite';
    final legacyDb = sqlite3.open(legacyPath);
    try {
      legacyDb
        ..execute(
          'CREATE TABLE currency (code TEXT PRIMARY KEY, locale TEXT, symbol TEXT, '
          'is_default INTEGER, is_active INTEGER, created_at TEXT, updated_at TEXT)',
        )
        ..execute(
          'CREATE TABLE account (serial_num TEXT PRIMARY KEY, name TEXT, type TEXT, '
          'balance TEXT, initial_balance TEXT, currency TEXT, is_shared INTEGER, '
          'is_virtual INTEGER, is_active INTEGER, created_at TEXT, updated_at TEXT)',
        )
        ..execute(
          'CREATE TABLE transactions (serial_num TEXT PRIMARY KEY, transaction_type TEXT, '
          'transaction_status TEXT, date TEXT, amount TEXT, currency TEXT, description TEXT, '
          'account_serial_num TEXT, category TEXT, sub_category TEXT, payment_method TEXT, '
          'created_at TEXT, updated_at TEXT)',
        )
        ..execute(
          'CREATE TABLE family_ledger (serial_num TEXT PRIMARY KEY, name TEXT, '
          'base_currency TEXT, ledger_type TEXT, status TEXT, created_at TEXT, updated_at TEXT)',
        )
        ..execute(
          'CREATE TABLE family_ledger_transaction (family_ledger_serial_num TEXT, '
          'transaction_serial_num TEXT, created_at TEXT, updated_at TEXT)',
        )
        ..execute(
          'CREATE TABLE installment_plans (serial_num TEXT PRIMARY KEY, '
          'transaction_serial_num TEXT, account_serial_num TEXT, total_amount TEXT, '
          'total_periods INTEGER, installment_amount TEXT, first_due_date TEXT, '
          'status TEXT, created_at TEXT, updated_at TEXT, total_interest TEXT)',
        )
        ..execute(
          'CREATE TABLE installment_details (serial_num TEXT PRIMARY KEY, '
          'plan_serial_num TEXT, period_number INTEGER, due_date TEXT, amount TEXT, '
          'account_serial_num TEXT, status TEXT, paid_date TEXT, created_at TEXT, updated_at TEXT)',
        )
        ..execute(
          'CREATE TABLE split_records (serial_num TEXT PRIMARY KEY, transaction_serial_num TEXT, '
          'family_ledger_serial_num TEXT, split_rule_serial_num TEXT, payer_member_serial_num TEXT, '
          'owe_member_serial_num TEXT, total_amount TEXT, split_amount TEXT, split_percentage TEXT, '
          'currency TEXT, status TEXT, split_type TEXT, notes TEXT, created_at TEXT, updated_at TEXT)',
        )
        ..execute(
          'CREATE TABLE split_record_details (serial_num TEXT PRIMARY KEY, '
          'split_record_serial_num TEXT, member_serial_num TEXT, amount TEXT, percentage TEXT, '
          'created_at TEXT, updated_at TEXT)',
        )
        ..execute(
          'CREATE TABLE budget (serial_num TEXT PRIMARY KEY, account_serial_num TEXT, name TEXT, '
          'amount TEXT, currency TEXT, repeat_period_type TEXT, repeat_period INTEGER, '
          'start_date TEXT, end_date TEXT, used_amount TEXT, is_active INTEGER, '
          'created_at TEXT, updated_at TEXT)',
        )
        ..execute(
          'CREATE TABLE budget_allocations (serial_num TEXT PRIMARY KEY, budget_serial_num TEXT, '
          'allocated_amount TEXT, used_amount TEXT, remaining_amount TEXT, allocation_type TEXT, '
          'alert_threshold INTEGER, status TEXT, created_at TEXT, updated_at TEXT)',
        )
        ..execute(
          "INSERT INTO currency VALUES ('CNY', 'zh_CN', '¥', 1, 1, "
          "'2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z')",
        )
        ..execute(
          "INSERT INTO account VALUES ('acct_1', '现金', 'Cash', '88.50', '100.00', "
          "'CNY', 0, 0, 1, '2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z')",
        )
        ..execute(
          "INSERT INTO transactions VALUES ('txn_1', 'Expense', 'Completed', "
          "'2026-01-03T00:00:00Z', '12.30', 'CNY', '午餐', 'acct_1', "
          "'餐饮', '午餐', 'Cash', '2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z')",
        )
        ..execute(
          "INSERT INTO family_ledger VALUES ('ledger_family_1', '家庭账本', 'CNY', "
          "'family', 'active', '2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z')",
        )
        ..execute(
          "INSERT INTO family_ledger_transaction VALUES ('ledger_family_1', 'txn_1', "
          "'2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z')",
        )
        ..execute(
          "INSERT INTO installment_plans VALUES ('plan_1', 'txn_1', 'acct_1', "
          "'120.00', 3, '40.00', '2026-02-01T00:00:00Z', 'Active', "
          "'2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z', '0')",
        )
        ..execute(
          "INSERT INTO installment_details VALUES ('detail_1', 'plan_1', 1, "
          "'2026-02-01T00:00:00Z', '40.00', 'acct_1', 'Pending', NULL, "
          "'2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z')",
        )
        ..execute(
          "INSERT INTO split_records VALUES ('split_1', 'txn_1', 'ledger_family_1', NULL, "
          "'member_1', 'member_1', '12.30', '12.30', '100', 'CNY', 'Active', "
          "'equal', '记录', '2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z')",
        )
        ..execute(
          "INSERT INTO split_record_details VALUES ('split_detail_1', 'split_1', 'member_1', "
          "'12.30', '100', '2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z')",
        )
        ..execute(
          "INSERT INTO budget VALUES ('budget_1', 'acct_1', '餐饮预算', '500.00', 'CNY', "
          "'Monthly', 1, '2026-01-01T00:00:00Z', '2026-01-31T00:00:00Z', '12.30', "
          "1, '2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z')",
        )
        ..execute(
          "INSERT INTO budget_allocations VALUES ('budget_allocation_1', 'budget_1', "
          "'500.00', '12.30', '487.70', 'fixed_amount', 80, 'active', "
          "'2026-01-02T03:04:05Z', '2026-01-02T03:04:05Z')",
        );
    } finally {
      legacyDb.close();
    }

    final service = LegacyMoneyImportService(database: appDatabase);
    final result = await service.importNow(
      LegacyMoneyImportOptions(
        sourcePath: legacyPath,
        userId: 'user_1',
        personalLedgerId: 'ledger_personal_1',
        defaultMemberId: 'member_1',
      ),
    );

    final accounts = await appDatabase.select(appDatabase.moneyAccounts).get();
    final transactions = await appDatabase
        .select(appDatabase.moneyTransactions)
        .get();
    final ledgerTransactions = await appDatabase
        .select(appDatabase.moneyLedgerTransactions)
        .get();
    final installmentPlans = await appDatabase
        .select(appDatabase.moneyInstallmentPlans)
        .get();
    final splitRecords = await appDatabase
        .select(appDatabase.moneySplitRecords)
        .get();
    final budgets = await appDatabase.select(appDatabase.moneyBudgets).get();
    final budgetAllocations = await appDatabase
        .select(appDatabase.moneyBudgetAllocations)
        .get();

    expect(result.countFor('account'), 1);
    expect(result.countFor('transactions'), 1);
    expect(accounts.single.balanceMinor, 8850);
    expect(transactions.single.amountMinor, 1230);
    expect(ledgerTransactions.map((item) => item.ledgerId).toSet(), {
      'ledger_personal_1',
      'ledger_family_1',
    });
    expect(installmentPlans.single.totalAmountMinor, 12000);
    expect(splitRecords.single.totalAmountMinor, 1230);
    expect(budgets.single.amountMinor, 50000);
    expect(budgetAllocations.single.remainingAmountMinor, 48770);
  });

  test('imports legacy transfer income and expense as transfer rows', () async {
    final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
    await appDatabase
        .into(appDatabase.users)
        .insert(
          UsersCompanion.insert(
            id: 'user_1',
            username: 'user_1',
            email: 'user_1@example.com',
            displayName: '用户',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final legacyPath =
        '${tempDir.path}${Platform.pathSeparator}legacy_transfer.json';
    File(legacyPath).writeAsStringSync(
      jsonEncode({
        'domains': {
          'currencies': [
            {
              'code': 'CNY',
              'locale': 'zh_CN',
              'symbol': '¥',
              'is_default': true,
              'is_active': true,
              'created_at': '2026-01-02T03:04:05Z',
              'updated_at': '2026-01-02T03:04:05Z',
            },
          ],
          'accounts': [
            {
              'serial_num': 'acct_1',
              'name': '现金',
              'type': 'Cash',
              'balance': '100.00',
              'initial_balance': '100.00',
              'currency': 'CNY',
              'is_shared': false,
              'is_virtual': false,
              'is_active': true,
              'created_at': '2026-01-02T03:04:05Z',
              'updated_at': '2026-01-02T03:04:05Z',
            },
          ],
          'transactions': [
            {
              'serial_num': 'txn_transfer_out',
              'transaction_type': 'Expense',
              'transaction_status': 'Completed',
              'date': '2026-01-03T00:00:00Z',
              'amount': '100.00',
              'currency': 'CNY',
              'description': '转账转出',
              'account_serial_num': 'acct_1',
              'category': 'Transfer',
              'sub_category': 'AccountTransfer',
              'payment_method': 'BankTransfer',
              'created_at': '2026-01-02T03:04:05Z',
              'updated_at': '2026-01-02T03:04:05Z',
            },
            {
              'serial_num': 'txn_transfer_in',
              'transaction_type': 'Income',
              'transaction_status': 'Completed',
              'date': '2026-01-03T00:00:00Z',
              'amount': '100.00',
              'currency': 'CNY',
              'description': '转账转入',
              'account_serial_num': 'acct_1',
              'category': 'Transfer',
              'sub_category': 'AccountTransfer',
              'payment_method': 'BankTransfer',
              'created_at': '2026-01-02T03:04:05Z',
              'updated_at': '2026-01-02T03:04:05Z',
            },
          ],
        },
      }),
    );

    final service = LegacyMoneyImportService(database: appDatabase);
    await service.importNow(
      LegacyMoneyImportOptions(
        sourcePath: legacyPath,
        userId: 'user_1',
        personalLedgerId: 'ledger_personal_1',
        defaultMemberId: 'member_1',
      ),
    );

    final transactions = await appDatabase
        .select(appDatabase.moneyTransactions)
        .get();
    final byId = {
      for (final transaction in transactions) transaction.id: transaction,
    };

    expect(
      byId['txn_transfer_out']?.type,
      MoneyTransactionType.transfer.storageValue,
    );
    expect(byId['txn_transfer_out']?.categoryId, 'system_transfer');
    expect(byId['txn_transfer_out']?.actualPayerAccount, 'transfer_out');
    expect(
      byId['txn_transfer_in']?.type,
      MoneyTransactionType.transfer.storageValue,
    );
    expect(byId['txn_transfer_in']?.categoryId, 'system_transfer');
    expect(byId['txn_transfer_in']?.actualPayerAccount, 'transfer_in');
  });

  test('imports real legacy json snapshot into money tables', () async {
    final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
    await appDatabase
        .into(appDatabase.users)
        .insert(
          UsersCompanion.insert(
            id: 'user_1',
            username: 'user_1',
            email: 'user_1@example.com',
            displayName: '用户',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final service = LegacyMoneyImportService(database: appDatabase);
    final result = await service.importNow(
      const LegacyMoneyImportOptions(
        sourcePath: 'docs/snap_2026-07-12T05-02-56.030566801+00-00.json',
        userId: 'user_1',
        personalLedgerId: 'ledger_personal_1',
        defaultMemberId: 'member_1',
      ),
    );

    final accounts = await appDatabase.select(appDatabase.moneyAccounts).get();
    final transactions = await appDatabase
        .select(appDatabase.moneyTransactions)
        .get();
    final ledgerTransactions = await appDatabase
        .select(appDatabase.moneyLedgerTransactions)
        .get();

    expect(result.countFor('account'), greaterThan(0));
    expect(result.countFor('transactions'), greaterThan(0));
    expect(accounts, isNotEmpty);
    expect(transactions, isNotEmpty);
    expect(ledgerTransactions, isNotEmpty);
  });
}
