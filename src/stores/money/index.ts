// src/stores/money/index.ts
/**
 * Money Store 模块导出
 *
 * 原 moneyStore.ts 已拆分为多个子模块：
 * - account-store: 账户管理
 * - budget-store: 预算管理
 * - category-store: 分类管理
 * - transaction-store: 交易管理
 * - reminder-store: 提醒管理
 *
 * 使用示例：
 * ```ts
 * import { useAccountStore, useBudgetStore, useTransactionStore } from '@/stores/money';
 *
 * const accountStore = useAccountStore();
 * await accountStore.fetchAccounts();
 *
 * const transactionStore = useTransactionStore();
 * await transactionStore.fetchTransactionsPaged(query);
 * ```
 */

// Store导出
export { useAccountStore } from './account-store';
export { useBudgetStore } from './budget-store';
export { useCategoryStore } from './category-store';
// 错误类和工具导出
export { handleMoneyStoreError, MoneyStoreError, MoneyStoreErrorCode } from './money-errors';
export { useReminderStore } from './reminder-store';

export { useTransactionStore } from './transaction-store';
