<script setup lang="ts">
import {
  ArrowRightLeft,
  Bell,
  CreditCard,
  MinusCircle,
  PlusCircle,
  Target,
} from 'lucide-vue-next';
import ConfirmModal from '@/components/common/ConfirmModal.vue';
import { useConfirm } from '@/composables/useConfirm';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { CategorySchema, TransactionTypeSchema } from '@/schema/common';
import { MoneyDb } from '@/services/money/money';
import { useMoneyStore } from '@/stores/moneyStore';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { uuid } from '@/utils/uuid';
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
import type { AppError } from '@/errors/appError';
import type { TransactionType } from '@/schema/common';
import type {
  Account,
  BilReminder,
  Budget,
  CreateAccountRequest,
  TransactionWithAccount,
  UpdateAccountRequest,
} from '@/schema/money';

// Add ref for TransactionList
const transactionListRef = ref<InstanceType<typeof TransactionList> | null>(null);

const moneyStore = useMoneyStore();
const { confirmState, confirmDelete, handleConfirm, handleCancel, handleClose } = useConfirm();

const activeTab = ref('accounts');
const baseCurrency = ref(CURRENCY_CNY.symbol);

const accountsLoading = ref(false);
const budgetsLoading = ref(false);
const remindersLoading = ref(false);

const showTransaction = ref(false);
const showAccount = ref(false);
const showBudget = ref(false);
const showReminder = ref(false);

const selectedTransaction = ref<TransactionWithAccount | null>(null);
const selectedAccount = ref<Account | null>(null);
const selectedBudget = ref<Budget | null>(null);
const selectedReminder = ref<BilReminder | null>(null);
const transactionType = ref<TransactionType>(
  TransactionTypeSchema.enum.Expense,
);

// Adding ref for StackedStatCards component
const stackedCardsRef = ref<InstanceType<typeof StackedStatCards> | null>(null);

const tabs = [
  { key: 'accounts', label: '账户' },
  { key: 'transactions', label: '交易' },
  { key: 'budgets', label: '预算' },
  { key: 'reminders', label: '提醒' },
];

const accounts = ref<Account[]>([]);
const budgets = ref<Budget[]>([]);
const reminders = ref<BilReminder[]>([]);

// const totalAssets = computed(() => {
//   return accounts.value
//     .filter(account => account.isActive)
//     .reduce((sum, account) => sum + Number.parseFloat(account.balance), 0);
// });
const totalAssets = ref(0);
const yearlyIncome = ref(0);
const yearlyExpense = ref(0);
const prevYearlyIncome = ref(0);
const prevYearlyExpense = ref(0);
const monthlyIncome = ref(0);
const monthlyExpense = ref(0);
const prevMonthlyIncome = ref(0);
const prevMonthlyExpense = ref(0);

const budgetRemaining = computed(() => {
  return budgets.value
    .filter(b => b.isActive)
    .reduce(
      (sum, b) => sum + (Number.parseFloat(b.amount) - Number.parseFloat(b.usedAmount)),
      0,
    );
});

// 统计卡片数据
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
      {
        label: '总预算',
        value: formatCurrency(20000),
        color: 'primary',
      },
      {
        label: '已使用',
        value: formatCurrency(5222),
        color: 'danger',
      },
    ],
  },
]);

// 计算是否有 Modal 打开
const hasModalOpen = computed(() => {
  return (
    showTransaction.value
    || showAccount.value
    || showBudget.value
    || showReminder.value
    || confirmState.value.visible
  );
});

// 监听并控制背景滚动和卡片自动播放
watchEffect(() => {
  if (hasModalOpen.value) {
    // 暂停卡片自动播放
    if (stackedCardsRef.value) {
      stackedCardsRef.value.stopAutoPlay();
    }

    const scrollY = window.scrollY;
    document.body.style.overflow = 'hidden';
    document.body.style.position = 'fixed';
    document.body.style.top = `-${scrollY}px`;
    document.body.style.width = '100%';
  } else {
    // 恢复卡片自动播放
    if (stackedCardsRef.value) {
      stackedCardsRef.value.startAutoPlay();
    }

    const scrollY = document.body.style.top;
    document.body.style.overflow = '';
    document.body.style.position = '';
    document.body.style.top = '';
    document.body.style.width = '';
    if (scrollY) {
      window.scrollTo(0, Number.parseInt(scrollY || '0') * -1);
    }
  }
});

async function loadData() {
  try {
    await Promise.all([
      loadAccounts(),
      loadBudgets(),
      loadReminders(),
      syncIncomeExpense(),
    ]);
  } catch (err) {
    Lg.e('loadData', err);
    toast.error('加载数据失败');
  }
}

async function loadAccounts() {
  accountsLoading.value = true;
  try {
    accounts.value = await moneyStore.getAccounts();
  } finally {
    accountsLoading.value = false;
  }
}

async function loadBudgets() {
  budgetsLoading.value = true;
  try {
    budgets.value = await moneyStore.getBudgets();
  } finally {
    budgetsLoading.value = false;
  }
}

async function loadReminders() {
  remindersLoading.value = true;
  try {
    reminders.value = await moneyStore.getReminders();
  } finally {
    remindersLoading.value = false;
  }
}

function showTransactionModal(type: TransactionType) {
  transactionType.value = type;
  selectedTransaction.value = null;
  showTransaction.value = true;
}

function editTransaction(transaction: TransactionWithAccount) {
  selectedTransaction.value = transaction;
  transactionType.value = transaction.transactionType;
  showTransaction.value = true;
}

async function deleteTransaction(transaction: TransactionWithAccount) {
  const confirmed = await confirmDelete('此交易记录');
  if (confirmed) {
    try {
      // 检查是否为转账交易
      if (transaction && isTransferTransaction(transaction)) {
        // 如果是转账交易，需要特殊处理
        await moneyStore.deleteTransferTransaction(transaction.serialNum);
        toast.success('转账记录删除成功');
      } else {
        // 普通交易删除
        await moneyStore.deleteTransaction(transaction.serialNum);
        toast.success('删除成功');
      }

      // Call TransactionList's refresh method
      if (transactionListRef.value) {
        await transactionListRef.value.refresh();
      }
      // 刷新相关数据
      await Promise.all([loadAccounts(), syncIncomeExpense()]);
    } catch (err) {
      const error = err as AppError;
      Lg.e('deleteTransaction', err);
      if (error?.getUserMessage && typeof error.getUserMessage === 'function') {
        toast.error(error.message);
      } else if (err instanceof Error) {
        toast.error(err.message || '删除失败');
      } else {
        toast.error('删除失败');
      }
    }
  }
}

// 判断是否为转账交易的辅助函数
function isTransferTransaction(transaction: TransactionWithAccount): boolean {
  return transaction.category === CategorySchema.enum.Transfer;
}

async function saveTransfer(fromTransaction: TransactionWithAccount, toTransaction: TransactionWithAccount) {
  try {
    // 如果是编辑转账交易
    if (selectedTransaction.value) {
      // 更新转出交易记录
      await moneyStore.updateTransaction(fromTransaction);
      // 对于编辑转账，需要找到对应的转入交易记录并更新
      await moneyStore.updateTransferToTransaction(toTransaction);
      toast.success('转账更新成功');
    } else {
      const fromSerialNum = uuid(38);
      fromTransaction.serialNum = fromSerialNum;
      fromTransaction.relatedTransactionSerialNum = fromSerialNum;
      toTransaction.serialNum = uuid(38);
      toTransaction.relatedTransactionSerialNum = fromSerialNum;

      // 创建新的转账交易
      // 先创建转出交易
      const createdFromTransaction = await moneyStore.createTransaction(fromTransaction);

      // 再创建转入交易，可以在这里建立关联关系
      toTransaction.notes = toTransaction.notes || `转账关联账户: ${createdFromTransaction.account.name}`;
      await moneyStore.createTransaction(toTransaction);

      toast.success('转账记录成功');
    }

    closeTransactionModal();
    // 刷新相关数据，包括 TransactionList 的 refresh 方法
    await Promise.all([
      loadAccounts(),
      transactionListRef.value ? transactionListRef.value.refresh() : Promise.resolve(),
      syncIncomeExpense(),
    ]);
  } catch (err) {
    Lg.e('saveTransfer', err);
    toast.error('转账保存失败');
  }
}

function viewTransactionDetails(transaction: TransactionWithAccount) {
  Lg.d('viewTransactionDetails', '查看交易详情:', transaction);
}

function closeTransactionModal() {
  showTransaction.value = false;
  selectedTransaction.value = null;
}

async function saveTransaction(transaction: TransactionWithAccount) {
  try {
    if (selectedTransaction.value) {
      await moneyStore.updateTransaction(transaction);
      toast.success('更新成功');
    } else {
      await moneyStore.createTransaction(transaction);
      toast.success('添加成功');
    }
    closeTransactionModal();
    // 刷新相关数据
    await Promise.all([
      loadAccounts(),
      transactionListRef.value ? transactionListRef.value.refresh() : Promise.resolve(),
      syncIncomeExpense(),
    ]);
  } catch (err) {
    Lg.e('saveTransaction', err);
    toast.error('保存失败');
  }
}

function showAccountModal() {
  selectedAccount.value = null;
  showAccount.value = true;
}

function editAccount(account: Account) {
  selectedAccount.value = account;
  showAccount.value = true;
}

async function deleteAccount(serialNum: string) {
  const confirmed = await confirmDelete('此账户');
  if (confirmed) {
    try {
      await moneyStore.deleteAccount(serialNum);
      toast.success('删除成功');
      loadAccounts();
      await syncAccountBalanceSummary();
    } catch (err) {
      Lg.e('deleteAccount', err);
      toast.error('删除失败');
    }
  }
}

async function toggleAccountActive(serialNum: string) {
  try {
    await moneyStore.toggleAccountActive(serialNum);
    toast.success('状态更新成功');
    loadAccounts();
    await syncAccountBalanceSummary();
  } catch (err) {
    Lg.e('toggleAccountActive', err);
    toast.error('状态更新失败');
  }
}

function closeAccountModal() {
  showAccount.value = false;
  selectedAccount.value = null;
}

async function saveAccount(account: CreateAccountRequest | UpdateAccountRequest) {
  try {
    if (selectedAccount.value && isUpdateAccountRequest(account)) {
      await moneyStore.updateAccount(account);
      toast.success('更新成功');
    } else {
      await moneyStore.createAccount(account);
      toast.success('添加成功');
    }
    closeAccountModal();
    loadAccounts();
    await syncAccountBalanceSummary();
  } catch (err) {
    Lg.e('saveAccount', err);
    toast.error('保存失败');
  }
}

function showBudgetModal() {
  selectedBudget.value = null;
  showBudget.value = true;
}

function editBudget(budget: Budget) {
  selectedBudget.value = budget;
  showBudget.value = true;
}

async function deleteBudget(serialNum: string) {
  const confirmed = await confirmDelete('此预算');
  if (confirmed) {
    try {
      await moneyStore.deleteBudget(serialNum);
      toast.success('删除成功');
      loadBudgets();
    } catch (err) {
      Lg.e('deleteBudget', err);
      toast.error('删除失败');
    }
  }
}

async function toggleBudgetActive(serialNum: string) {
  try {
    await moneyStore.toggleBudgetActive(serialNum);
    toast.success('状态更新成功');
    loadBudgets();
  } catch (err) {
    Lg.e('toggleBudgetActive', err);
    toast.error('状态更新失败');
  }
}

function closeBudgetModal() {
  showBudget.value = false;
  selectedBudget.value = null;
}

async function saveBudget(budget: Budget) {
  try {
    if (selectedBudget.value) {
      await moneyStore.updateBudget(budget);
      toast.success('更新成功');
    } else {
      await moneyStore.createBudget(budget);
      toast.success('添加成功');
    }
    closeBudgetModal();
    loadBudgets();
  } catch (err) {
    Lg.e('saveBudget', err);
    toast.error('保存失败');
  }
}

function showReminderModal() {
  selectedReminder.value = null;
  showReminder.value = true;
}

function editReminder(reminder: BilReminder) {
  selectedReminder.value = reminder;
  showReminder.value = true;
}

async function deleteReminder(serialNum: string) {
  const confirmed = await confirmDelete('此提醒');
  if (confirmed) {
    try {
      await moneyStore.deleteReminder(serialNum);
      toast.success('删除成功');
      loadReminders();
    } catch (err) {
      Lg.e('deleteReminder', err);
      toast.error('删除失败');
    }
  }
}

async function markReminderPaid(serialNum: string) {
  try {
    await moneyStore.markReminderPaid(serialNum);
    toast.success('标记成功');
    loadReminders();
  } catch (err) {
    Lg.e('markReminderPaid', err);
    toast.error('标记失败');
  }
}

function closeReminderModal() {
  showReminder.value = false;
  selectedReminder.value = null;
}

async function saveReminder(reminder: BilReminder) {
  try {
    if (selectedReminder.value) {
      await moneyStore.updateReminder(reminder);
      toast.success('更新成功');
    } else {
      await moneyStore.createReminder(reminder);
      toast.success('添加成功');
    }
    closeReminderModal();
    loadReminders();
  } catch (err) {
    Lg.e('saveReminder', err);
    toast.error('保存失败');
  }
}

// 卡片事件处理 - 当有模态框打开时不执行
function handleCardChange(index: number, card: any) {
  // 如果有模态框打开，不执行任何操作
  if (hasModalOpen.value) {
    return;
  }

  Lg.d('handleCardChange', '卡片切换:', index, card.title);
}

function handleCardClick(_index: number, card: any) {
  // 如果有模态框打开，不执行任何操作
  if (hasModalOpen.value) {
    return;
  }
  Lg.i('MoneyView', card);
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

function isUpdateAccountRequest(
  account: CreateAccountRequest | UpdateAccountRequest,
): account is UpdateAccountRequest {
  return 'serialNum' in account;
}

onMounted(async () => {
  loadData();
  const currency = await getLocalCurrencyInfo();
  baseCurrency.value = currency.symbol;
});
</script>

<template>
  <div class="mx-auto max-w-1200px p-5">
    <!-- 头部统计卡片 - 扑克牌叠放样式 -->
    <StackedStatCards
      ref="stackedCardsRef"
      :cards="statCards"
      :auto-play="true"
      :auto-play-delay="8000"
      :show-nav-buttons="true"
      :show-play-control="false"
      :card-width="320"
      :card-height="176"
      :enable-keyboard="true"
      :max-visible-cards="4"
      :transition-duration="600"
      :disabled="hasModalOpen"
      @card-change="handleCardChange"
      @card-click="handleCardClick"
    />

    <!-- 主要功能区域 -->
    <div class="overflow-hidden rounded-lg bg-white shadow-[0_2px_4px_rgba(0,0,0,0.1)]">
      <!-- 快速操作 -->
      <div class="border-b border-gray-200 p-5">
        <div class="mb-3.75 flex flex-wrap items-center justify-between gap-y-3">
          <!-- 快捷操作标题靠左 -->
          <h3 class="m-0 text-gray-800">
            快捷操作
          </h3>
          <!-- 操作按钮靠右 -->
          <div class="flex flex-wrap justify-end gap-3.75">
            <button
              class="flex cursor-pointer items-center gap-2 rounded-md border-none bg-purple-50 px-2 py-3 text-sm text-purple-500 transition-all duration-200 hover:opacity-80 hover:-translate-y-0.25"
              @click="showAccountModal"
            >
              <CreditCard class="h-4 w-4" />
              <span>添加账户</span>
            </button>
            <button
              class="flex cursor-pointer items-center gap-2 rounded-md border-none bg-green-50 px-2 py-3 text-sm text-green-600 transition-all duration-200 hover:opacity-80 hover:-translate-y-0.25"
              @click="showTransactionModal(TransactionTypeSchema.enum.Income)"
            >
              <PlusCircle class="h-4 w-4" />
              <span>记录收入</span>
            </button>
            <button
              class="flex cursor-pointer items-center gap-2 rounded-md border-none bg-red-50 px-2 py-3 text-sm text-red-500 transition-all duration-200 hover:opacity-80 hover:-translate-y-0.25"
              @click="showTransactionModal(TransactionTypeSchema.enum.Expense)"
            >
              <MinusCircle class="h-4 w-4" />
              <span>记录支出</span>
            </button>
            <button
              class="flex cursor-pointer items-center gap-2 rounded-md border-none bg-blue-50 px-2 py-3 text-sm text-blue-500 transition-all duration-200 hover:opacity-80 hover:-translate-y-0.25"
              @click="showTransactionModal(TransactionTypeSchema.enum.Transfer)"
            >
              <ArrowRightLeft class="h-4 w-4" />
              <span>记录转账</span>
            </button>
            <button
              class="flex cursor-pointer items-center gap-2 rounded-md border-none bg-orange-50 px-2 py-3 text-sm text-orange-500 transition-all duration-200 hover:opacity-80 hover:-translate-y-0.25"
              @click="showBudgetModal"
            >
              <Target class="h-4 w-4" />
              <span>设置预算</span>
            </button>
            <button
              class="flex cursor-pointer items-center gap-2 rounded-md border-none bg-yellow-50 px-2 py-3 text-sm text-yellow-600 transition-all duration-200 hover:opacity-80 hover:-translate-y-0.25"
              @click="showReminderModal"
            >
              <Bell class="h-4 w-4" />
              <span>设置提醒</span>
            </button>
          </div>
        </div>
      </div>

      <!-- 标签页切换 -->
      <div class="flex justify-center overflow-x-auto border-b border-gray-200">
        <button
          v-for="tab in tabs" :key="tab.key" class="border-b-2 border-transparent px-6 py-3 text-sm text-gray-600 font-medium transition-all duration-200 hover:border-blue-300 hover:text-blue-500" :class="[
            activeTab === tab.key && 'text-blue-600 border-b-[3px] border-blue-600 bg-blue-50 rounded-t-md',
          ]" @click="activeTab = tab.key"
        >
          {{ tab.label }}
        </button>
      </div>

      <!-- 内容区域 -->
      <div class="p-5">
        <!-- 账户管理 -->
        <div v-if="activeTab === 'accounts'" class="accounts-section">
          <AccountList
            :accounts="accounts" :loading="accountsLoading" @edit="editAccount" @delete="deleteAccount"
            @toggle-active="toggleAccountActive"
          />
        </div>

        <!-- 交易记录 -->
        <div v-if="activeTab === 'transactions'" class="transactions-section">
          <TransactionList
            ref="transactionListRef"
            :accounts="accounts"
            @edit="editTransaction"
            @delete="deleteTransaction"
            @view-details="viewTransactionDetails"
          />
        </div>

        <!-- 预算管理 -->
        <div v-if="activeTab === 'budgets'" class="budgets-section">
          <BudgetList
            :budgets="budgets" :loading="budgetsLoading" @edit="editBudget" @delete="deleteBudget"
            @toggle-active="toggleBudgetActive"
          />
        </div>

        <!-- 账单提醒 -->
        <div v-if="activeTab === 'reminders'" class="reminders-section">
          <ReminderList
            :reminders="reminders" :loading="remindersLoading" @edit="editReminder" @delete="deleteReminder"
            @mark-paid="markReminderPaid"
          />
        </div>
      </div>
    </div>

    <!-- 模态框 -->
    <TransactionModal
      v-if="showTransaction"
      :type="transactionType"
      :transaction="selectedTransaction"
      :accounts="accounts"
      @close="closeTransactionModal"
      @save="saveTransaction"
      @save-transfer="saveTransfer"
    />

    <AccountModal v-if="showAccount" :account="selectedAccount" @close="closeAccountModal" @save="saveAccount" />

    <BudgetModal v-if="showBudget" :budget="selectedBudget" @close="closeBudgetModal" @save="saveBudget" />

    <ReminderModal v-if="showReminder" :reminder="selectedReminder" @close="closeReminderModal" @save="saveReminder" />

    <!-- 确认模态框 -->
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

<style lang="postcss">
.btn-div {
  @apply flex justify-end items-center mb-3;
}

.btn {
  @apply flex items-center gap-1 px-3 py-1.5 border-none rounded-md cursor-pointer text-xs bg-[#1890ff] text-white transition-all duration-200 hover:bg-[#40a9ff];
}

/* 或者只对特定容器隐藏滚动条 */
.main-container {
  overflow-y: auto;
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.main-container::-webkit-scrollbar {
  display: none;
}
</style>
