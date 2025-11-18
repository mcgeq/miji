/**
 * 账户过滤 Composable
 *
 * 职责：
 * - 根据交易类型过滤可用账户
 * - 处理不同交易类型的账户限制
 */

import { computed } from 'vue';
import { AccountTypeSchema } from '@/schema/money';
import type { TransactionType } from '@/schema/common';
import type { Account } from '@/schema/money';
import type { Ref } from 'vue';

export function useAccountFilter(
  accounts: Ref<Account[]>,
  transactionType: Ref<TransactionType>,
  category?: Ref<string | undefined>,
) {
  /**
   * 可选择的账户列表
   * 根据交易类型和分类进行过滤
   */
  const selectableAccounts = computed(() => {
    // 只显示激活的账户
    const activeAccounts = accounts.value.filter(acc => acc.isActive);

    // 转账类型：返回所有激活账户
    if (category?.value === 'Transfer') {
      return activeAccounts;
    }

    // 收入类型：排除信用卡账户
    // 原因：收入不应该直接到信用卡（通常是还款操作）
    if (transactionType.value === 'Income') {
      return activeAccounts.filter(
        acc => acc.type !== AccountTypeSchema.enum.CreditCard,
      );
    }

    // 支出类型：返回所有激活账户
    return activeAccounts;
  });

  /**
   * 检查账户是否可用
   */
  function isAccountSelectable(accountSerialNum: string): boolean {
    return selectableAccounts.value.some(
      acc => acc.serialNum === accountSerialNum,
    );
  }

  /**
   * 获取默认选中的账户
   */
  const defaultAccount = computed(() => {
    return selectableAccounts.value[0] || null;
  });

  return {
    selectableAccounts,
    isAccountSelectable,
    defaultAccount,
  };
}
