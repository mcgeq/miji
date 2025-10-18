<script setup lang="ts">
import { listen } from '@tauri-apps/api/event';
import ConfirmModal from '@/components/common/ConfirmModal.vue';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { TransactionTypeSchema } from '@/schema/common';
import { MoneyDb } from '@/services/money/money';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { createComparisonCard } from '../common/moneyCommon';
import AccountList from '../components/AccountList.vue';
import AccountModal from '../components/AccountModal.vue';
import BudgetList from '../components/BudgetList.vue';
import BudgetModal from '../components/BudgetModal.vue';
import ReminderList from '../components/ReminderList.vue';
import ReminderModal from '../components/ReminderModal.vue';
import StackedStatCards from '../components/StackedStatCards.vue';
import TransactionList from '../components/TransactionList.vue';
import TransactionModal from '../components/TransactionModal.vue';
import { formatCurrency, getLocalCurrencyInfo } from '../utils/money';
import type { CardData } from '../common/moneyCommon';
// 事件类型定义
interface InstallmentProcessedEvent {
  processed_count: number;
  timestamp: number;
}

interface InstallmentProcessFailedEvent {
  error: string;
  timestamp: number;
}

// ------------------ Refs ------------------
const transactionListRef = ref<InstanceType<typeof TransactionList> | null>(null);
const budgetListRef = ref<InstanceType<typeof BudgetList> | null>(null);
const reminderListRef = ref<InstanceType<typeof ReminderList> | null>(null);
const stackedCardsRef = ref<InstanceType<typeof StackedStatCards> | null>(null);

const moneyStore = useMoneyStore();
const { confirmState, confirmDelete, handleConfirm, handleCancel, handleClose } = useConfirm();

// 使用各个功能模块的 hooks
const {
  showTransaction,
  selectedTransaction,
  transactionType,
  isViewMode,
  showTransactionModal,
  closeTransactionModal,
  editTransaction,
  viewTransactionDetails,
  handleSaveTransaction,
  handleUpdateTransaction,
  handleDeleteTransaction,
  handleSaveTransfer,
  handleUpdateTransfer,
} = useTransactionActions();

const {
  showAccount,
  selectedAccount,
  accounts,
  accountsLoading,
  showAccountModal,
  closeAccountModal,
  editAccount,
  loadAccountsWithLoading,
  handleSaveAccount,
  handleUpdateAccount,
  handleDeleteAccount,
  handleToggleAccountActive,
} = useAccountActions();

const {
  showBudget,
  selectedBudget,
  showBudgetModal,
  closeBudgetModal,
  editBudget,
  handleSaveBudget,
  handleUpdateBudget,
  handleDeleteBudget,
  handleToggleBudgetActive,
} = useBudgetActions();

const {
  showReminder,
  selectedReminder,
  showReminderModal,
  closeReminderModal,
  editReminder,
  handleSaveReminder,
  handleUpdateReminder,
  handleDeleteReminder,
  handleMarkReminderPaid,
} = useReminderActions();

const activeTab = ref('accounts');
const baseCurrency = ref(CURRENCY_CNY.symbol);

const tabs = [
  { key: 'accounts', label: '账户' },
  { key: 'transactions', label: '交易' },
  { key: 'budgets', label: '预算' },
  { key: 'reminders', label: '提醒' },
];

// ------------------ 响应式卡片尺寸 ------------------
const cardDimensions = reactive({
  width: 320,
  height: 176,
});

function updateCardDimensions() {
  if (window.innerWidth <= 768) {
    // 移动端
    cardDimensions.width = 200;
    cardDimensions.height = 128;
  } else {
    // 桌面端
    cardDimensions.width = 320;
    cardDimensions.height = 176;
  }
};

const totalAssets = ref(0);
const yearlyIncome = ref(0);
const yearlyExpense = ref(0);
const prevYearlyIncome = ref(0);
const prevYearlyExpense = ref(0);
const monthlyIncome = ref(0);
const monthlyExpense = ref(0);
const prevMonthlyIncome = ref(0);
const prevMonthlyExpense = ref(0);

const budgetRemaining = ref(0);

const statCards = computed<CardData[]>(() => [
  {
    id: 'total-assets',
    title: '总资产',
    value: formatCurrency(totalAssets.value),
    currency: baseCurrency.value,
    icon: 'wallet',
    color: 'primary' as const,
  },
  createComparisonCard(
    'monthly-income-comparison',
    '月度收入',
    formatCurrency(monthlyIncome.value),
    formatCurrency(prevMonthlyIncome.value),
    '上月',
    baseCurrency.value,
    'trending-up',
    'success',
  ),
  createComparisonCard(
    'yearly-income-comparison',
    '年度收入',
    formatCurrency(yearlyIncome.value),
    formatCurrency(prevYearlyIncome.value),
    '去年',
    baseCurrency.value,
    'trending-up',
    'primary',
  ),
  createComparisonCard(
    'monthly-expense-comparison',
    '月度支出',
    formatCurrency(monthlyExpense.value),
    formatCurrency(prevMonthlyExpense.value),
    '上月',
    baseCurrency.value,
    'trending-up',
    'success',
  ),
  createComparisonCard(
    'yearly-expense-comparison',
    '年度支出',
    formatCurrency(yearlyExpense.value),
    formatCurrency(prevYearlyExpense.value),
    '去年',
    baseCurrency.value,
    'trending-up',
    'primary',
  ),
  {
    id: 'budget-overview',
    title: '预算总览',
    value: formatCurrency(budgetRemaining.value),
    currency: baseCurrency.value,
    icon: 'target',
    color: 'warning',
    subtitle: '本月剩余',
    extraStats: [
      { label: '总预算', value: formatCurrency(20000), color: 'primary' },
      { label: '已使用', value: formatCurrency(5222), color: 'danger' },
    ],
  },
]);

const hasModalOpen = computed(() =>
  showTransaction.value || showAccount.value || showBudget.value || showReminder.value || confirmState.value.visible,
);

// ------------------ Watch Modal ------------------
watchEffect(() => {
  if (hasModalOpen.value) {
    if (stackedCardsRef.value) stackedCardsRef.value.stopAutoPlay();
    const scrollY = window.scrollY;
    document.body.style.overflow = 'hidden';
    document.body.style.position = 'fixed';
    document.body.style.top = `-${scrollY}px`;
    document.body.style.width = '100%';
  } else {
    if (stackedCardsRef.value) stackedCardsRef.value.startAutoPlay();
    const scrollY = document.body.style.top;
    document.body.style.overflow = '';
    document.body.style.position = '';
    document.body.style.top = '';
    document.body.style.width = '';
    if (scrollY) window.scrollTo(0, Number.parseInt(scrollY || '0') * -1);
  }
});

// ------------------ Common Finalize ------------------
async function finalizeChange(closeFn: () => void, refreshFns: Array<() => Promise<void> | void>) {
  closeFn();
  for (const fn of refreshFns) {
    await fn();
  }
}

function finalizeAccountChange() {
  return finalizeChange(closeAccountModal, [
    async () => {
      await loadAccountsWithLoading();
    },
    syncAccountBalanceSummary,
  ]);
}
function finalizeTransactionChange() {
  return finalizeChange(closeTransactionModal, [
    async () => transactionListRef.value?.refresh(),
    async () => {
      await loadAccountsWithLoading();
    },
    syncIncomeExpense,
  ]);
}
function finalizeBudgetChange() {
  return finalizeChange(closeBudgetModal, [
    async () => budgetListRef.value?.refresh(),
  ]);
}

function finalizeReminderChange() {
  return finalizeChange(closeReminderModal, [
    async () => reminderListRef.value?.refresh(),
  ]);
}

// ------------------ Load & Sync ------------------
async function loadData() {
  try {
    await Promise.all([loadAccountsWithLoading(), syncIncomeExpense()]);
  } catch (err) {
    Lg.e('loadData', err);
    toast.error('加载数据失败');
  }
}

async function syncIncomeExpense() {
  await syncAccountBalanceSummary();
  const m = await MoneyDb.monthlyIncomeAndExpense();
  const lm = await MoneyDb.lastMonthIncomeAndExpense();
  const y = await MoneyDb.yearlyIncomeAndExpense();
  const ly = await MoneyDb.lastYearIncomeAndExpense();
  monthlyIncome.value = m.income.total;
  monthlyExpense.value = m.expense.total;
  prevMonthlyIncome.value = lm.income.total;
  prevMonthlyExpense.value = lm.expense.total;
  yearlyIncome.value = y.income.total;
  yearlyExpense.value = y.expense.total;
  prevYearlyIncome.value = ly.income.total;
  prevYearlyExpense.value = ly.expense.total;
}

async function syncAccountBalanceSummary() {
  const t = await MoneyDb.totalAssets();
  totalAssets.value = t.totalAssets;
}

// ------------------ Account ------------------
// 账户相关功能现在由 useAccountActions hook 提供

// ------------------ Transaction ------------------
// 交易相关功能现在由 useTransactionActions hook 提供

// ------------------ Budget ------------------
// 预算相关功能现在由 useBudgetActions hook 提供

// ------------------ Reminder ------------------
// 提醒相关功能现在由 useReminderActions hook 提供

// ------------------ Card Events ------------------
function handleCardChange(index: number, card: any) {
  if (hasModalOpen.value) return;
  Lg.d('handleCardChange', '卡片切换:', index, card.title);
}
function handleCardClick(_index: number, _card: any) {
}

// ------------------ Amount Visibility ------------------
function toggleGlobalAmountVisibility() {
  moneyStore.toggleGlobalAmountVisibility();
}

onMounted(async () => {
  loadData();
  const currency = await getLocalCurrencyInfo();
  baseCurrency.value = currency.symbol;
  // 监听分期处理完成事件
  const unlistenProcessed = await listen<InstallmentProcessedEvent>('installment-processed', event => {
    Lg.d('installment-processed', '收到分期处理完成事件:', event.payload);
    // 刷新账户数据
    loadAccountsWithLoading();
    // 刷新交易列表
    transactionListRef.value?.refresh();
    // 显示通知
    toast.success(`自动处理了 ${event.payload.processed_count} 笔分期交易`);
  });
  // 监听分期处理失败事件
  const unlistenFailed = await listen<InstallmentProcessFailedEvent>('installment-process-failed', event => {
    Lg.d('installment-process-failed', '收到分期处理失败事件:', event.payload);
    // 显示错误通知
    toast.error(`分期处理失败: ${event.payload.error}`);
  });
  // 在组件卸载时清理监听器
  onUnmounted(() => {
    unlistenProcessed();
    unlistenFailed();
  });
});

onMounted(async () => {
  await moneyStore.getAllCategories();
  await moneyStore.getAllSubCategories();
});

// 生命周期钩子
onMounted(() => {
  updateCardDimensions(); // 初始加载时设置
  window.addEventListener('resize', updateCardDimensions);
});

onUnmounted(() => {
  window.removeEventListener('resize', updateCardDimensions);
});
</script>

<template>
  <div class="container">
    <!-- 统计卡片轮播 -->
    <StackedStatCards
      ref="stackedCardsRef"
      :cards="statCards"
      :auto-play="true"
      :auto-play-delay="8000"
      :show-nav-buttons="true"
      :show-play-control="false"
      :card-width="cardDimensions.width"
      :card-height="cardDimensions.height"
      :enable-keyboard="true"
      :max-visible-cards="4"
      :transition-duration="600"
      :disabled="hasModalOpen"
      @card-change="handleCardChange"
      @card-click="handleCardClick"
    />

    <!-- 快捷操作 & Tabs -->
    <div class="panel">
      <div class="panel-header">
        <div class="quick-actions-wrapper">
          <div class="quick-actions scroll-x">
            <button class="btn btn-purple" @click="showAccountModal">
              <LucideCreditCard /><span>添加账户</span>
            </button>
            <button class="btn btn-green" @click="showTransactionModal(TransactionTypeSchema.enum.Income)">
              <LucidePlusCircle /><span>记录收入</span>
            </button>
            <button class="btn btn-red" @click="showTransactionModal(TransactionTypeSchema.enum.Expense)">
              <LucideMinusCircle /><span>记录支出</span>
            </button>
            <button class="btn btn-blue" @click="showTransactionModal(TransactionTypeSchema.enum.Transfer)">
              <LucideArrowRightLeft /><span>记录转账</span>
            </button>
            <button class="btn btn-orange" @click="showBudgetModal">
              <LucideTarget /><span>设置预算</span>
            </button>
            <button class="btn btn-yellow" @click="showReminderModal">
              <LucideBell /><span>设置提醒</span>
            </button>
            <!-- 可以继续添加按钮 -->
          </div>
          <!-- 左右渐变遮罩 -->
          <div class="fade fade-left" />
          <div class="fade fade-right" />
        </div>
      </div>
      <!-- Tabs -->
      <div class="tabs">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          class="m-tab-btn"
          :class="[activeTab === tab.key ? 'active' : '']"
          @click="activeTab = tab.key"
        >
          {{ tab.label }}
        </button>
        <button
          class="btn-hide"
          :class="moneyStore.globalAmountHidden ? 'btn-gray' : 'btn-blue'"
          @click="toggleGlobalAmountVisibility"
        >
          <LucideEye v-if="!moneyStore.globalAmountHidden" />
          <LucideEyeOff v-else />
        </button>
      </div>

      <!-- Tab 内容 -->
      <div class="tab-content">
        <AccountList
          v-if="activeTab === 'accounts'"
          :accounts="accounts"
          :loading="accountsLoading"
          @edit="editAccount"
          @delete="(serialNum) => handleDeleteAccount(serialNum, confirmDelete, finalizeAccountChange)"
          @toggle-active="(serialNum, isActive) => handleToggleAccountActive(serialNum, isActive, finalizeAccountChange)"
        />
        <TransactionList
          v-if="activeTab === 'transactions'"
          ref="transactionListRef"
          :accounts="accounts"
          @edit="editTransaction"
          @delete="(transaction) => handleDeleteTransaction(transaction, confirmDelete, finalizeTransactionChange)"
          @view-details="viewTransactionDetails"
        />
        <BudgetList
          v-if="activeTab === 'budgets'"
          ref="budgetListRef"
          @edit="editBudget"
          @delete="(serialNum) => handleDeleteBudget(serialNum, confirmDelete, finalizeBudgetChange)"
          @toggle-active="(serialNum, isActive) => handleToggleBudgetActive(serialNum, isActive, finalizeBudgetChange)"
        />
        <ReminderList
          v-if="activeTab === 'reminders'"
          ref="reminderListRef"
          @edit="editReminder"
          @delete="(serialNum) => handleDeleteReminder(serialNum, confirmDelete, finalizeReminderChange)"
          @mark-paid="(serialNum, isPaid) => handleMarkReminderPaid(serialNum, isPaid, finalizeReminderChange)"
        />
      </div>
    </div>

    <!-- Modals -->
    <TransactionModal
      v-if="showTransaction"
      :type="transactionType"
      :transaction="selectedTransaction"
      :accounts="accounts"
      :readonly="isViewMode"
      @close="closeTransactionModal"
      @save="(transaction) => handleSaveTransaction(transaction, finalizeTransactionChange)"
      @update="(serialNum, transaction) => handleUpdateTransaction(serialNum, transaction, finalizeTransactionChange)"
      @save-transfer="(transfer) => handleSaveTransfer(transfer, finalizeTransactionChange)"
      @update-transfer="(serialNum, transfer) => handleUpdateTransfer(serialNum, transfer, finalizeTransactionChange)"
    />
    <AccountModal
      v-if="showAccount"
      :account="selectedAccount"
      @close="closeAccountModal"
      @save="(account) => handleSaveAccount(account, finalizeAccountChange)"
      @update="(serialNum, account) => handleUpdateAccount(serialNum, account, finalizeAccountChange)"
    />
    <BudgetModal
      v-if="showBudget"
      :budget="selectedBudget"
      @close="closeBudgetModal"
      @save="(budget) => handleSaveBudget(budget, finalizeBudgetChange)"
      @update="(serialNum, budget) => handleUpdateBudget(serialNum, budget, finalizeBudgetChange)"
    />
    <ReminderModal
      v-if="showReminder"
      :reminder="selectedReminder"
      @close="closeReminderModal"
      @save="(reminder) => handleSaveReminder(reminder, finalizeReminderChange)"
      @update="(serialNum, reminder) => handleUpdateReminder(serialNum, reminder, finalizeReminderChange)"
    />

    <ConfirmModal
      :visible="confirmState.visible"
      :title="confirmState.title"
      :message="confirmState.message"
      :type="confirmState.type"
      :confirm-text="confirmState.confirmText"
      :cancel-text="confirmState.cancelText"
      :confirm-button-type="confirmState.confirmButtonType"
      :show-cancel="confirmState.showCancel"
      :loading="confirmState.loading"
      @confirm="handleConfirm"
      @cancel="handleCancel"
      @close="handleClose"
    />
  </div>
</template>

<style>
/* 快捷操作横向滚动 */
.scroll-x {
  display: flex;
  flex-wrap: nowrap; /* 不换行 */
  gap: 12px;
  overflow-x: auto;
  -webkit-overflow-scrolling: touch; /* 平滑滚动 */
  scrollbar-width: none; /* Firefox 隐藏滚动条 */
  position: relative;
  padding: 8px 0; /* 给渐变遮罩留空间 */
}

.scroll-x::-webkit-scrollbar {
  display: none; /* Chrome/Safari 隐藏滚动条 */
}

/* 容器 */
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

/* 面板 */
.panel {
  background-color: #fff;
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  overflow: hidden;
  margin-top: 2px;
}

.panel-header {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  align-items: center;
  padding: 20px;
  border-bottom: 1px solid #e5e5e5;
  background-color: var(--color-base-100);
}

.panel-header h3 {
  margin: 0;
  color: #333;
  margin-right: 20px; /* 标题与按钮之间的间距 */
}

/* 快捷操作按钮 */
.quick-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  justify-content: center;
}

.btn {
  flex-shrink: 0; /* 防止按钮被压缩 */
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  font-size: 14px;
  font-weight: 500;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  transition: opacity 0.2s;
}

.btn:hover {
  opacity: 0.8;
}

.btn-purple { background-color: #f3e8ff; color: #8b5cf6; }
.btn-green { background-color: #dcfce7; color: #16a34a; }
.btn-red { background-color: #fee2e2; color: #ef4444; }
.btn-blue { background-color: #dbeafe; color: #3b82f6; }
.btn-orange { background-color: #ffedd5; color: #f97316; }
.btn-yellow { background-color: #fef9c3; color: #ca8a04; }
.btn-gray { background-color: #f3f4f6; color: #6b7280; }

.btn-hide {
  flex-shrink: 0; /* 防止按钮被压缩 */
  padding: 0.5rem 1rem;
  font-weight: 500;
  border-radius: 0.5rem;
  cursor: pointer;
  transition: opacity 0.2s;
}

.btn-hide:hover {
  opacity: 0.8;
}

/* Tabs */
.tabs {
  display: flex;
  overflow-x: auto;
  border: 1px solid var(--color-base-300);
  justify-content: center;
  background-color: var(--color-base-100);
}

.m-tab-btn {
  flex-shrink: 0;
  padding: 12px 24px;
  font-size: 14px;
  font-weight: 500;
  color: #666;
  background: transparent;
  border: none;
  border-bottom: 3px solid transparent;
  cursor: pointer;
  transition: all 0.2s;
}

.m-tab-btn.active {
  color: var(--color-base-content);
  border-color: var(--color-neutral);
  background-color: var(--color-base-200);
  border-top-left-radius: 6px;
  border-top-right-radius: 6px;
}

/* Tab 内容 */
.tab-content {
  padding: 20px;
  background-color: var(--color-base-100);
}

/* 滚动条隐藏 */
.container::-webkit-scrollbar {
  display: none;
}
.container {
  -ms-overflow-style: none;
  scrollbar-width: none;
}

/* 响应式调整 */
@media (max-width: 768px) {
  .panel-header {
    flex-direction: column; /* 移动端标题和按钮垂直排列 */
    text-align: center; /* 标题居中 */
  }

  .panel-header h3 {
    margin-right: 0; /* 移除标题与按钮的间距 */
    margin-bottom: 10px; /* 标题与按钮之间的间距 */
  }

  .btn {
    padding: 6px 10px; /* 移动端减少内边距 */
    font-size: 12px; /* 缩小字体 */
  }

  .container {
    padding: 10px; /* 减少内边距 */
  }
}

@media (min-width: 769px) and (max-width: 1200px) {
  .container {
    max-width: 1000px; /* 中等屏幕适配 */
  }

  .btn {
    padding: 8px 14px; /* 适中内边距 */
  }
}

/* 渐变遮罩 */
.quick-actions-wrapper {
  position: relative;
}

.fade {
  position: absolute;
  top: 0;
  bottom: 0;
  width: 32px;
  pointer-events: none; /* 不阻挡滚动 */
}
</style>
