import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';

enum MoneyAccountDisplayGroupKind {
  assets,
  creditAndDebt,
  inactive;

  String get title {
    return switch (this) {
      MoneyAccountDisplayGroupKind.assets => '资产账户',
      MoneyAccountDisplayGroupKind.creditAndDebt => '信用/负债账户',
      MoneyAccountDisplayGroupKind.inactive => '停用账户',
    };
  }
}

class MoneyAccountDisplayGroup {
  const MoneyAccountDisplayGroup({required this.kind, required this.accounts});

  final MoneyAccountDisplayGroupKind kind;
  final List<MoneyAccountEntity> accounts;
}

class MoneyCreditStatementSummary {
  const MoneyCreditStatementSummary({
    required this.amountDueByCurrency,
    required this.availableCreditByCurrency,
    required this.dueSoonCount,
    required this.overdueCount,
  });

  final Map<String, int> amountDueByCurrency;
  final Map<String, int> availableCreditByCurrency;
  final int dueSoonCount;
  final int overdueCount;

  bool get hasStatements =>
      amountDueByCurrency.isNotEmpty || availableCreditByCurrency.isNotEmpty;
}

List<MoneyAccountDisplayGroup> buildMoneyAccountDisplayGroups(
  List<MoneyAccountEntity> accounts,
) {
  final assets = <MoneyAccountEntity>[];
  final creditAndDebt = <MoneyAccountEntity>[];
  final inactive = <MoneyAccountEntity>[];

  for (final account in accounts) {
    if (!account.isActive) {
      inactive.add(account);
    } else if (account.type.isCreditLike || account.type.isDebtLike) {
      creditAndDebt.add(account);
    } else {
      assets.add(account);
    }
  }

  return [
    if (assets.isNotEmpty)
      MoneyAccountDisplayGroup(
        kind: MoneyAccountDisplayGroupKind.assets,
        accounts: assets,
      ),
    if (creditAndDebt.isNotEmpty)
      MoneyAccountDisplayGroup(
        kind: MoneyAccountDisplayGroupKind.creditAndDebt,
        accounts: creditAndDebt,
      ),
    if (inactive.isNotEmpty)
      MoneyAccountDisplayGroup(
        kind: MoneyAccountDisplayGroupKind.inactive,
        accounts: inactive,
      ),
  ];
}

MoneyCreditStatementSummary summarizeCreditAccountStatements(
  Iterable<MoneyCreditCardStatement> statements,
) {
  final amountDueByCurrency = <String, int>{};
  final availableCreditByCurrency = <String, int>{};
  var dueSoonCount = 0;
  var overdueCount = 0;

  for (final statement in statements) {
    amountDueByCurrency.update(
      statement.currencyCode,
      (value) => value + statement.amountDueMinor,
      ifAbsent: () => statement.amountDueMinor,
    );
    availableCreditByCurrency.update(
      statement.currencyCode,
      (value) => value + statement.availableCreditMinor,
      ifAbsent: () => statement.availableCreditMinor,
    );
    switch (statement.state) {
      case MoneyCreditCardStatementState.dueSoon:
        dueSoonCount += 1;
      case MoneyCreditCardStatementState.overdue:
        overdueCount += 1;
      case MoneyCreditCardStatementState.open ||
          MoneyCreditCardStatementState.pending ||
          MoneyCreditCardStatementState.settled:
        break;
    }
  }

  return MoneyCreditStatementSummary(
    amountDueByCurrency: Map.unmodifiable(amountDueByCurrency),
    availableCreditByCurrency: Map.unmodifiable(availableCreditByCurrency),
    dueSoonCount: dueSoonCount,
    overdueCount: overdueCount,
  );
}
