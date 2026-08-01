import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_content.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_dialog.dart';

class TransactionDetailPanel extends StatelessWidget {
  const TransactionDetailPanel({
    super.key,
    required this.transaction,
    required this.accounts,
    required this.expenseCatalog,
    required this.incomeCatalog,
    required this.onClose,
    this.onEdit,
    this.onDelete,
    this.onRefund,
    this.onAddSplit,
    this.onAddToFamilyLedger,
    this.onRemoveFromFamilyLedger,
    this.onEditSplit,
    this.onCancelSplit,
  });

  final MoneyTransactionEntity transaction;
  final List<MoneyAccountEntity> accounts;
  final MoneyCategoryCatalog expenseCatalog;
  final MoneyCategoryCatalog incomeCatalog;
  final VoidCallback onClose;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRefund;
  final VoidCallback? onAddSplit;
  final VoidCallback? onAddToFamilyLedger;
  final ValueChanged<MoneyLedgerEntity>? onRemoveFromFamilyLedger;
  final ValueChanged<MoneySplitRecordEntity>? onEditSplit;
  final ValueChanged<MoneySplitRecordEntity>? onCancelSplit;

  @override
  Widget build(BuildContext context) {
    return AppListItemPanel(
      padding: EdgeInsets.zero,
      child: TransactionDetailFrame(
        onClose: onClose,
        fillHeight: true,
        child: TransactionDetailContent(
          transaction: transaction,
          accounts: accounts,
          expenseCatalog: expenseCatalog,
          incomeCatalog: incomeCatalog,
          onEdit: onEdit,
          onDelete: onDelete,
          onRefund: onRefund,
          onAddSplit: onAddSplit,
          onAddToFamilyLedger: onAddToFamilyLedger,
          onRemoveFromFamilyLedger: onRemoveFromFamilyLedger,
          onEditSplit: onEditSplit,
          onCancelSplit: onCancelSplit,
        ),
      ),
    );
  }
}
