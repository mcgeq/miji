// src/stores/money/index.ts
/**
 * Money Store 模块导出
 *
 * 原 moneyStore.ts 已拆分为多个子模块：
 * - account-store: 账户管理
 * - budget-store: 预算管理
 * - category-store: 分类管理
 *
 * 使用示例：
 * ```ts
 * import { useAccountStore, useBudgetStore } from '@/stores/money';
 *
 * const accountStore = useAccountStore();
 * await accountStore.fetchAccounts();
 * ```
 */

export { useAccountStore } from './account-store';
export { useBudgetStore } from './budget-store';
export { useCategoryStore } from './category-store';
