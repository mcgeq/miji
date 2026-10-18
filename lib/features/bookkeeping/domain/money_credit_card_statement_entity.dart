import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

enum MoneyCreditCardStatementState {
  open,
  pending,
  dueSoon,
  overdue,
  settled;

  String get label {
    return switch (this) {
      MoneyCreditCardStatementState.open => '未出账',
      MoneyCreditCardStatementState.pending => '待还款',
      MoneyCreditCardStatementState.dueSoon => '临近还款',
      MoneyCreditCardStatementState.overdue => '已逾期',
      MoneyCreditCardStatementState.settled => '已还清',
    };
  }
}

class MoneyCreditCardStatement {
  const MoneyCreditCardStatement({
    required this.accountId,
    required this.currencyCode,
    required this.periodStart,
    required this.periodEndExclusive,
    required this.repaymentDate,
    required this.purchaseAmountMinor,
    required this.repaymentAmountMinor,
    required this.amountDueMinor,
    required this.availableCreditMinor,
    required this.postedDebtMinor,
    required this.state,
    this.pendingReconciliationItems =
        const <MoneyCreditCardReconciliationItem>[],
    this.transactions = const <MoneyTransactionEntity>[],
  });

  final String accountId;
  final String currencyCode;
  final DateTime periodStart;
  final DateTime periodEndExclusive;
  final DateTime repaymentDate;
  final int purchaseAmountMinor;
  final int repaymentAmountMinor;
  final int amountDueMinor;
  final int availableCreditMinor;
  final int postedDebtMinor;
  final MoneyCreditCardStatementState state;
  final List<MoneyCreditCardReconciliationItem> pendingReconciliationItems;
  final List<MoneyTransactionEntity> transactions;

  DateTime get periodEndInclusive {
    return periodEndExclusive.subtract(const Duration(milliseconds: 1));
  }

  bool get hasPendingReconciliation {
    return pendingReconciliationItems.isNotEmpty;
  }
}

class MoneyCreditCardReconciliationItem {
  const MoneyCreditCardReconciliationItem({
    required this.title,
    required this.amountMinor,
    this.transactionId,
    this.notes,
  });

  final String title;
  final int amountMinor;
  final String? transactionId;
  final String? notes;
}
