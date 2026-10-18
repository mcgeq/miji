import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_content.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';

/// 单笔流水的独立页面。
///
/// 为什么需要它：流水详情一直只有弹层（`showTransactionDetailDialog`），
/// 而那要求调用方手里**已经有那个实体**。跨模块时间线、通知、深链接都只有
/// 一个 id，所以这里用 id 去取一次，再复用同一份 [TransactionDetailContent] ——
/// 布局、口径、操作都只有一份实现。
class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transaction = ref.watch(transactionByIdProvider(transactionId));
    return Scaffold(
      appBar: AppBar(title: const Text('流水详情')),
      body: transaction.when(
        loading: () => const AppSkeletonList(rows: 4),
        error: (error, stackTrace) => Center(
          child: TextButton(
            onPressed: () =>
                ref.invalidate(transactionByIdProvider(transactionId)),
            child: const Text('读取失败 · 重试'),
          ),
        ),
        data: (value) => value == null
            ? const Center(child: Text('这笔流水已经不在了'))
            : _TransactionDetailBody(transaction: value),
      ),
    );
  }
}

class _TransactionDetailBody extends ConsumerWidget {
  const _TransactionDetailBody({required this.transaction});

  final MoneyTransactionEntity transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(currentUserVisibleAccountsProvider).asData?.value ?? const [];
    final expenseCatalog =
        ref
            .watch(
              currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
            )
            .asData
            ?.value ??
        const MoneyCategoryCatalog.empty();
    final incomeCatalog =
        ref
            .watch(currentUserCategoryCatalogProvider(MoneyCategoryKind.income))
            .asData
            ?.value ??
        const MoneyCategoryCatalog.empty();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: TransactionDetailContent(
        transaction: transaction,
        accounts: accounts,
        expenseCatalog: expenseCatalog,
        incomeCatalog: incomeCatalog,
        // 编辑走同一张表单弹层；改完回到这一页，数据随 provider 刷新。
        onEdit: () => showAppResponsiveDialog<void>(
          context: context,
          expandCompactSheet: true,
          builder: (_) => TransactionFormDialog(
            type: transaction.type,
            transaction: transaction,
          ),
        ),
        onDelete: null,
        onRefund: null,
        onDuplicate: null,
      ),
    );
  }
}

/// 按 id 取一笔流水。null = 不存在（已删、或不属于当前用户）。
final transactionByIdProvider = FutureProvider.autoDispose
    .family<MoneyTransactionEntity?, String>((ref, id) async {
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return null;
      }
      try {
        return await ref
            .watch(moneyRepositoryProvider)
            .getTransactionForUser(session.userId!, id);
      } catch (_) {
        // 仓库在「找不到」时抛异常；对页面来说「没有这笔」和「读取失败」要分开，
        // 所以这里把它翻译成 null，真正的读取失败才走 error 分支。
        return null;
      }
    });
