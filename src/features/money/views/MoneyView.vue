<script setup lang="ts">
import { listen } from '@tauri-apps/api/event';
import { Eye, EyeOff } from 'lucide-vue-next';
import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
import { Button as UiButton } from '@/components/ui';
import { useMoneyStats } from '@/composables/useMoneyStats';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { TransactionTypeSchema } from '@/schema/common';
import { MoneyDb } from '@/services/money/money';
import { useCategoryStore, useMoneyConfigStore } from '@/stores/money';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import AccountList from '../components/AccountList.vue';
import AccountModal from '../components/AccountModal.vue';
import BudgetList from '../components/BudgetList.vue';
import BudgetModal from '../components/BudgetModal.vue';
import ReminderList from '../components/ReminderList.vue';
import ReminderModal from '../components/ReminderModal.vue';
import StackedStatCards from '../components/StackedStatCards.vue';
import TransactionList from '../components/TransactionList.vue';
import TransactionModal from '../components/TransactionModal.vue';
import { getLocalCurrencyInfo } from '../utils/money';
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

const categoryStore = useCategoryStore();
const moneyConfigStore = useMoneyConfigStore();
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

const { t } = useI18n();

const activeTab = ref('accounts');
const baseCurrency = ref(CURRENCY_CNY.code);

const tabs = computed(() => [
  { key: 'accounts', label: t('financial.quickActions.accounts') },
  { key: 'transactions', label: t('financial.quickActions.transactions') },
  { key: 'budgets', label: t('financial.quickActions.budgets') },
  { key: 'reminders', label: t('financial.quickActions.reminders') },
]);

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

// 使用 useMoneyStats composable 生成统计卡片
const { statCards } = useMoneyStats(computed(() => ({
  totalAssets: totalAssets.value,
  monthlyIncome: monthlyIncome.value,
  prevMonthlyIncome: prevMonthlyIncome.value,
  yearlyIncome: yearlyIncome.value,
  prevYearlyIncome: prevYearlyIncome.value,
  monthlyExpense: monthlyExpense.value,
  prevMonthlyExpense: prevMonthlyExpense.value,
  yearlyExpense: yearlyExpense.value,
  prevYearlyExpense: prevYearlyExpense.value,
  baseCurrency: baseCurrency.value,
})));

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
    await Promise.all([
      loadAccountsWithLoading(),
      syncIncomeExpense(),
    ]);
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
  moneyConfigStore.toggleGlobalAmountHidden();
}

// 存储监听器清理函数
let unlistenProcessed: (() => void) | null = null;
let unlistenFailed: (() => void) | null = null;

// 在组件卸载时清理监听器
onUnmounted(() => {
  if (unlistenProcessed) {
    unlistenProcessed();
  }
  if (unlistenFailed) {
    unlistenFailed();
  }
});

onMounted(async () => {
  loadData();
  const currency = await getLocalCurrencyInfo();
  baseCurrency.value = currency.code;
  // 监听分期处理完成事件
  unlistenProcessed = await listen<InstallmentProcessedEvent>('installment-processed', event => {
    Lg.d('installment-processed', '收到分期处理完成事件:', event.payload);
    // 刷新账户数据
    loadAccountsWithLoading();
    // 刷新交易列表
    transactionListRef.value?.refresh();
    // 显示通知
    toast.success(`自动处理了 ${event.payload.processed_count} 笔分期交易`);
  });
  // 监听分期处理失败事件
  unlistenFailed = await listen<InstallmentProcessFailedEvent>('installment-process-failed', event => {
    Lg.d('installment-process-failed', '收到分期处理失败事件:', event.payload);
    // 显示错误通知
    toast.error(`分期处理失败: ${event.payload.error}`);
  });
});

onMounted(async () => {
  await categoryStore.fetchCategories();
  await categoryStore.fetchSubCategories();
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
  <div class="w-full max-w-7xl mx-auto p-5 md:p-8 overflow-x-hidden">
    <!-- 统计卡片轮播 -->
    <div class="w-full max-w-[55rem] mx-auto">
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
    </div>

    <!-- 快捷操作 & Tabs -->
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md overflow-hidden mt-0.5 w-full max-w-[55rem] mx-auto">
      <div class="flex justify-center items-center px-3 py-4 border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800">
        <div class="flex flex-wrap justify-center gap-2 md:gap-3">
          <button class="flex-shrink-0 flex items-center justify-center gap-1.5 px-3 md:px-4 py-2 text-sm font-medium bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 border-none rounded-md cursor-pointer transition-opacity hover:opacity-80" @click="showAccountModal">
            <LucideCreditCard class="w-4 h-4 flex-shrink-0" /><span class="whitespace-nowrap hidden sm:inline">{{ t('financial.quickActions.account') }}</span>
          </button>
          <button class="flex-shrink-0 flex items-center justify-center gap-1.5 px-3 md:px-4 py-2 text-sm font-medium bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400 border-none rounded-md cursor-pointer transition-opacity hover:opacity-80" @click="showTransactionModal(TransactionTypeSchema.enum.Income)">
            <LucidePlusCircle class="w-4 h-4 flex-shrink-0" /><span class="whitespace-nowrap hidden sm:inline">{{ t('financial.quickActions.income') }}</span>
          </button>
          <button class="flex-shrink-0 flex items-center justify-center gap-1.5 px-3 md:px-4 py-2 text-sm font-medium bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400 border-none rounded-md cursor-pointer transition-opacity hover:opacity-80" @click="showTransactionModal(TransactionTypeSchema.enum.Expense)">
            <LucideMinusCircle class="w-4 h-4 flex-shrink-0" /><span class="whitespace-nowrap hidden sm:inline">{{ t('financial.quickActions.expense') }}</span>
          </button>
          <button class="flex-shrink-0 flex items-center justify-center gap-1.5 px-3 md:px-4 py-2 text-sm font-medium bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 border-none rounded-md cursor-pointer transition-opacity hover:opacity-80" @click="showTransactionModal(TransactionTypeSchema.enum.Transfer)">
            <LucideArrowRightLeft class="w-4 h-4 flex-shrink-0" /><span class="whitespace-nowrap hidden sm:inline">{{ t('financial.quickActions.transfer') }}</span>
          </button>
          <button class="flex-shrink-0 flex items-center justify-center gap-1.5 px-3 md:px-4 py-2 text-sm font-medium bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400 border-none rounded-md cursor-pointer transition-opacity hover:opacity-80" @click="showBudgetModal">
            <LucideTarget class="w-4 h-4 flex-shrink-0" /><span class="whitespace-nowrap hidden sm:inline">{{ t('financial.quickActions.budget') }}</span>
          </button>
          <button class="flex-shrink-0 flex items-center justify-center gap-1.5 px-3 md:px-4 py-2 text-sm font-medium bg-yellow-100 dark:bg-yellow-900/30 text-yellow-600 dark:text-yellow-400 border-none rounded-md cursor-pointer transition-opacity hover:opacity-80" @click="showReminderModal">
            <LucideBell class="w-4 h-4 flex-shrink-0" /><span class="whitespace-nowrap hidden sm:inline">{{ t('financial.quickActions.reminder') }}</span>
          </button>
        </div>
      </div>
      <!-- Tabs -->
      <div class="flex overflow-x-auto border-t border-gray-300 dark:border-gray-700 justify-center bg-white dark:bg-gray-800">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          class="flex-shrink-0 px-6 py-3 text-sm font-medium border-b-3 cursor-pointer transition-all" :class="[
            activeTab === tab.key
              ? 'text-gray-900 dark:text-gray-100 border-gray-600 dark:border-gray-400 bg-gray-100 dark:bg-gray-700 rounded-t-md'
              : 'text-gray-600 dark:text-gray-400 border-transparent bg-transparent',
          ]"
          @click="activeTab = tab.key"
        >
          {{ tab.label }}
        </button>
        <UiButton
          variant="ghost"
          size="md"
          circle
          :icon="moneyConfigStore.globalAmountHidden ? EyeOff : Eye"
          @click="toggleGlobalAmountVisibility"
        />
      </div>

      <!-- Tab 内容 -->
      <div class="bg-white dark:bg-gray-800 min-h-full p-4 sm:p-6 md:p-8">
        <AccountList
          v-if="activeTab === 'accounts'"
          :accounts="accounts"
          :loading="accountsLoading"
          @edit="editAccount"
          @delete="(serialNum) => handleDeleteAccount(serialNum, confirmDelete, finalizeAccountChange)"
          @toggle-active="(serialNum) => handleToggleAccountActive(serialNum, finalizeAccountChange)"
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
          @toggle-active="(serialNum) => handleToggleBudgetActive(serialNum, finalizeBudgetChange)"
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

    <ConfirmDialog
      :visible="confirmState.visible"
      :title="confirmState.title"
      :message="confirmState.message"
      :type="confirmState.type"
      :confirm-text="confirmState.confirmText"
      :cancel-text="confirmState.cancelText"
      :confirm-button-type="confirmState.confirmButtonType"
      :show-cancel="confirmState.showCancel"
      :loading="confirmState.loading"
      :icon-buttons="true"
      @confirm="handleConfirm"
      @cancel="handleCancel"
      @close="handleClose"
    />
  </div>
</template>
