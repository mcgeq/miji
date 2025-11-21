// src/stores/money/index.ts
/**
 * Money Store 模块导出
 *
 * 模块化的 Money Store，按功能领域拆分为：
 * - account-store: 账户管理（账户CRUD、余额、可见性控制）
 * - budget-store: 预算管理（预算CRUD、使用情况）
 * - category-store: 分类管理（分类、子分类、缓存）
 * - transaction-store: 交易管理（收入、支出、转账、统计）
 * - reminder-store: 提醒管理（账单提醒、状态管理）
 * - money-errors: 统一错误处理（错误码、错误类、工具函数）
 *
 * 使用示例：
 * ```typescript
 * import { useAccountStore, useTransactionStore } from '@/stores/money';
 *
 * const accountStore = useAccountStore();
 * await accountStore.fetchAccounts();
 * console.log(accountStore.totalBalance);
 *
 * const transactionStore = useTransactionStore();
 * await transactionStore.createTransaction(data);
 * ```
 */

// Store导出
export { useAccountStore } from './account-store';
export { useBudgetStore } from './budget-store';
export { useCategoryStore } from './category-store';
export { useCurrencyStore } from './currency-store';
export { useFamilyLedgerStore } from './family-ledger-store';
export { useFamilyMemberStore } from './family-member-store';
export { useFamilySplitStore } from './family-split-store';
// 初始化函数导出
export { initMoneyStores } from './init';
export { useMoneyConfigStore } from './money-config-store';
// 错误类和工具导出
export { handleMoneyStoreError, MoneyStoreError, MoneyStoreErrorCode } from './money-errors';

export { useReminderStore } from './reminder-store';
// 事件系统导出
export { emitStoreEvent, onStoreEvent, storeEventBus } from './store-events';

export type { EventCleanup, StoreEvents } from './store-events';

export { useTransactionStore } from './transaction-store';
