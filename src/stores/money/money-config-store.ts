// src/stores/money/money-config-store.ts
import { defineStore } from 'pinia';

/**
 * Money 模块配置 Store
 * 使用 @tauri-store/pinia 自动持久化用户偏好设置
 */
export const useMoneyConfigStore = defineStore('money-config', () => {
  // ==================== 状态 ====================

  /**
   * 全局金额隐藏开关
   */
  const globalAmountHidden = ref(false);

  /**
   * 默认货币代码
   */
  const defaultCurrency = ref('CNY');

  /**
   * 默认账户类型
   */
  const defaultAccountType = ref('BankSavings');

  /**
   * 默认交易类型
   */
  const defaultTransactionType = ref<'Income' | 'Expense' | 'Transfer'>('Expense');

  /**
   * 列表显示偏好
   */
  const listPreferences = ref({
    accountsPageSize: 10,
    transactionsPageSize: 20,
    budgetsPageSize: 10,
    remindersPageSize: 10,
  });

  /**
   * 图表显示偏好
   */
  const chartPreferences = ref({
    showLegend: true,
    showDataLabels: true,
    animationEnabled: true,
  });

  // ==================== 计算属性 ====================

  const isAmountVisible = computed(() => !globalAmountHidden.value);

  // ==================== 方法 ====================

  /**
   * 切换全局金额显示/隐藏
   */
  function toggleGlobalAmountHidden() {
    globalAmountHidden.value = !globalAmountHidden.value;
  }

  /**
   * 设置默认货币
   */
  function setDefaultCurrency(currency: string) {
    defaultCurrency.value = currency;
  }

  /**
   * 设置默认账户类型
   */
  function setDefaultAccountType(type: string) {
    defaultAccountType.value = type;
  }

  /**
   * 设置默认交易类型
   */
  function setDefaultTransactionType(type: 'Income' | 'Expense' | 'Transfer') {
    defaultTransactionType.value = type;
  }

  /**
   * 更新列表分页大小
   */
  function updateListPageSize(listType: keyof typeof listPreferences.value, pageSize: number) {
    listPreferences.value[listType] = pageSize;
  }

  /**
   * 更新图表偏好
   */
  function updateChartPreferences(preferences: Partial<typeof chartPreferences.value>) {
    chartPreferences.value = { ...chartPreferences.value, ...preferences };
  }

  /**
   * 重置所有配置为默认值
   */
  function resetToDefaults() {
    globalAmountHidden.value = false;
    defaultCurrency.value = 'CNY';
    defaultAccountType.value = 'BankSavings';
    defaultTransactionType.value = 'Expense';
    listPreferences.value = {
      accountsPageSize: 10,
      transactionsPageSize: 20,
      budgetsPageSize: 10,
      remindersPageSize: 10,
    };
    chartPreferences.value = {
      showLegend: true,
      showDataLabels: true,
      animationEnabled: true,
    };
  }

  return {
    // 状态
    globalAmountHidden: readonly(globalAmountHidden),
    defaultCurrency: readonly(defaultCurrency),
    defaultAccountType: readonly(defaultAccountType),
    defaultTransactionType: readonly(defaultTransactionType),
    listPreferences: readonly(listPreferences),
    chartPreferences: readonly(chartPreferences),

    // 计算属性
    isAmountVisible,

    // 方法
    toggleGlobalAmountHidden,
    setDefaultCurrency,
    setDefaultAccountType,
    setDefaultTransactionType,
    updateListPageSize,
    updateChartPreferences,
    resetToDefaults,
  };
});
