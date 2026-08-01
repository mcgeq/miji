import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_content.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

Future<void> showTransactionDetailDialog({
  required BuildContext context,
  required MoneyTransactionEntity transaction,
  required List<MoneyAccountEntity> accounts,
  required MoneyCategoryCatalog expenseCatalog,
  required MoneyCategoryCatalog incomeCatalog,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onRefund,
  VoidCallback? onAddSplit,
  VoidCallback? onAddToFamilyLedger,
  ValueChanged<MoneyLedgerEntity>? onRemoveFromFamilyLedger,
  ValueChanged<MoneySplitRecordEntity>? onEditSplit,
  ValueChanged<MoneySplitRecordEntity>? onCancelSplit,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return _TransactionDetailDialogFrame(
        child: TransactionDetailContent(
          transaction: transaction,
          accounts: accounts,
          expenseCatalog: expenseCatalog,
          incomeCatalog: incomeCatalog,
          onEdit: _closeDialogAndRun(context, onEdit),
          onDelete: _closeDialogAndRun(context, onDelete),
          onRefund: _closeDialogAndRun(context, onRefund),
          onAddSplit: _closeDialogAndRun(context, onAddSplit),
          onAddToFamilyLedger: _closeDialogAndRun(context, onAddToFamilyLedger),
          onRemoveFromFamilyLedger: _closeDialogAndRunValue(
            context,
            onRemoveFromFamilyLedger,
          ),
          onEditSplit: _closeDialogAndRunValue(context, onEditSplit),
          onCancelSplit: _closeDialogAndRunValue(context, onCancelSplit),
        ),
      );
    },
  );
}

Future<void> showTransactionDetailProviderDialog({
  required BuildContext context,
  required MoneyTransactionEntity transaction,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  VoidCallback? onRefund,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return _TransactionDetailProviderDialog(
        transaction: transaction,
        onEdit: onEdit,
        onDelete: onDelete,
        onRefund: onRefund,
      );
    },
  );
}

class _TransactionDetailProviderDialog extends ConsumerWidget {
  const _TransactionDetailProviderDialog({
    required this.transaction,
    this.onEdit,
    this.onDelete,
    this.onRefund,
  });

  final MoneyTransactionEntity transaction;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRefund;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(currentUserVisibleAccountsProvider);
    final expenseCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
    );
    final incomeCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.income),
    );

    if (accounts.isLoading ||
        expenseCatalog.isLoading ||
        incomeCatalog.isLoading) {
      return const _TransactionDetailDialogFrame(
        child: SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (accounts.hasError ||
        expenseCatalog.hasError ||
        incomeCatalog.hasError) {
      return _TransactionDetailDialogFrame(
        child: SizedBox(
          height: 180,
          child: Center(
            child: Text(
              '读取流水详情失败',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return _TransactionDetailDialogFrame(
      child: TransactionDetailContent(
        transaction: transaction,
        accounts: accounts.maybeWhen(
          data: (items) => items,
          orElse: () => const <MoneyAccountEntity>[],
        ),
        expenseCatalog: expenseCatalog.maybeWhen(
          data: (catalog) => catalog,
          orElse: () => const MoneyCategoryCatalog.empty(),
        ),
        incomeCatalog: incomeCatalog.maybeWhen(
          data: (catalog) => catalog,
          orElse: () => const MoneyCategoryCatalog.empty(),
        ),
        onEdit: _closeDialogAndRun(context, onEdit),
        onDelete: _closeDialogAndRun(context, onDelete),
        onRefund: _closeDialogAndRun(context, onRefund),
      ),
    );
  }
}

VoidCallback? _closeDialogAndRun(BuildContext context, VoidCallback? action) {
  if (action == null) {
    return null;
  }

  return () {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    action();
  };
}

ValueChanged<T>? _closeDialogAndRunValue<T>(
  BuildContext context,
  ValueChanged<T>? action,
) {
  if (action == null) {
    return null;
  }

  return (value) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    action(value);
  };
}

class TransactionDetailFrame extends StatelessWidget {
  const TransactionDetailFrame({
    super.key,
    required this.child,
    required this.onClose,
    this.fillHeight = false,
    this.bottomPadding = 0,
  });

  final Widget child;
  final VoidCallback onClose;
  final bool fillHeight;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;

    final scrollView = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        spacing.cardPadding,
        spacing.cardPadding,
        spacing.cardPadding,
        spacing.cardPadding + bottomPadding,
      ),
      child: child,
    );

    return Column(
      mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.cardPadding + 42,
                ),
                child: Text(
                  '流水详情',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                child: AppIconActionButton(
                  tooltip: '关闭详情',
                  onPressed: onClose,
                  icon: Icons.close_rounded,
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colorScheme.outlineVariant),
        if (fillHeight)
          Expanded(child: scrollView)
        else
          Flexible(child: scrollView),
      ],
    );
  }
}

class _TransactionDetailDialogFrame extends StatelessWidget {
  const _TransactionDetailDialogFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final media = MediaQuery.of(context);
    final responsive = AppResponsive.of(context);
    final maxWidth = responsive.isCompact ? 520.0 : 540.0;
    final maxHeight =
        media.size.height -
        media.viewInsets.vertical -
        media.padding.vertical -
        48;
    final resolvedMaxHeight = maxHeight.clamp(360.0, 760.0).toDouble();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: responsive.isCompact ? 16 : 32,
        vertical: 24,
      ),
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: resolvedMaxHeight,
        ),
        child: Material(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(radius.lg),
          clipBehavior: Clip.antiAlias,
          child: TransactionDetailFrame(
            onClose: () => Navigator.of(context).pop(),
            bottomPadding: media.padding.bottom,
            child: child,
          ),
        ),
      ),
    );
  }
}
