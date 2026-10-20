import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

/// 账户弹窗里流水列表的一次取数请求。
///
/// 用「已加载条数」而不是页码：`listTransactions` 是 offset 分页，
/// 但弹窗只想把新一页**追加**在已有列表后面。让 `limit` 随「加载更多」
/// 增长，provider 返回的就是「前 N 条」的完整快照 —— 不需要在 widget 里
/// 拼接两段结果，也不会出现「筛选条件变了但列表还留着旧页」。
///
/// 相等性必须实现：它是 `family` 的 key，key 不等就会重新取数。
class AccountFlowRequest {
  const AccountFlowRequest({
    required this.accountId,
    this.type,
    this.dateStart,
    this.dateEnd,
    this.limit = AccountFlowRequest.pageSize,
  });

  static const pageSize = 20;

  final String accountId;

  /// `null` = 不限类型（支出 / 收入 / 转账都算）。
  final MoneyTransactionType? type;
  final DateTime? dateStart;
  final DateTime? dateEnd;

  /// 已加载条数上限。
  final int limit;

  AccountFlowRequest copyWith({
    String? accountId,
    MoneyTransactionType? type,
    bool clearType = false,
    DateTime? dateStart,
    DateTime? dateEnd,
    bool clearRange = false,
    int? limit,
  }) {
    return AccountFlowRequest(
      accountId: accountId ?? this.accountId,
      type: clearType ? null : (type ?? this.type),
      dateStart: clearRange ? null : (dateStart ?? this.dateStart),
      dateEnd: clearRange ? null : (dateEnd ?? this.dateEnd),
      limit: limit ?? this.limit,
    );
  }

  MoneyTransactionQuery toQuery() {
    return MoneyTransactionQuery(
      page: 1,
      pageSize: limit,
      accountId: accountId,
      type: type,
      dateStart: dateStart,
      dateEnd: dateEnd,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AccountFlowRequest &&
        other.accountId == accountId &&
        other.type == type &&
        other.dateStart == dateStart &&
        other.dateEnd == dateEnd &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(accountId, type, dateStart, dateEnd, limit);
}

const _emptyPage = MoneyTransactionPage(
  items: <MoneyTransactionEntity>[],
  page: 1,
  pageSize: 0,
  hasMore: false,
  total: 0,
);

/// 账户弹窗的流水页。
///
/// 口径提醒：按 `accountId` 过滤时**会包含转账的两条记录**（转出 / 转入各一条，
/// 转入行带 `transfer_in` 标记），而账户月度汇总排除了转账 ——
/// 所以概览里必须写「不含转账」，否则「合计 5 笔、列表 7 条」会被当成 bug。
final accountFlowPageProvider = FutureProvider.autoDispose
    .family<MoneyTransactionPage, AccountFlowRequest>((ref, request) async {
      // 记账模块统一的刷新信号：新增 / 编辑 / 删除流水后自动重取。
      ref.watch(moneyDataRefreshVersionProvider);
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (!session.isUnlocked || userId == null) {
        return _emptyPage;
      }
      return ref
          .watch(moneyRepositoryProvider)
          .listTransactions(userId, request.toQuery());
    });
