// src/stores/money/init.ts
import { useAccountStore } from './account-store';
import { useFamilyLedgerStore } from './family-ledger-store';

/**
 * 初始化 Money Store 模块
 * 在应用启动时调用，设置事件监听器等
 */
export function initMoneyStores() {
  // 初始化 Account Store 的事件监听器
  const accountStore = useAccountStore();
  accountStore.initEventListeners();

  // 初始化 Family Ledger Store 的事件监听器
  const familyLedgerStore = useFamilyLedgerStore();
  familyLedgerStore.initEventListeners();
}
