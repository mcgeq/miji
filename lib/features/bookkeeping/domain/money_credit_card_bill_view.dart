import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

enum MoneyCreditCardBillViewSource {
  issuedStatement,
  accountDebt,
  unbilled;

  String get label {
    return switch (this) {
      MoneyCreditCardBillViewSource.issuedStatement => '已出账',
      MoneyCreditCardBillViewSource.accountDebt => '当前欠款',
      MoneyCreditCardBillViewSource.unbilled => '未出账',
    };
  }
}

class MoneyCreditCardBillView {
  const MoneyCreditCardBillView({
    required this.accountId,
    required this.currencyCode,
    required this.source,
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
  final MoneyCreditCardBillViewSource source;
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

  MoneyCreditCardStatement toStatement() {
    return MoneyCreditCardStatement(
      accountId: accountId,
      currencyCode: currencyCode,
      periodStart: periodStart,
      periodEndExclusive: periodEndExclusive,
      repaymentDate: repaymentDate,
      purchaseAmountMinor: purchaseAmountMinor,
      repaymentAmountMinor: repaymentAmountMinor,
      amountDueMinor: amountDueMinor,
      availableCreditMinor: availableCreditMinor,
      postedDebtMinor: postedDebtMinor,
      state: state,
      pendingReconciliationItems: pendingReconciliationItems,
      transactions: transactions,
    );
  }
}
