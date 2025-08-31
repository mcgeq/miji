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
  BilReminderCreate,
  BilReminderUpdate,
  Budget,
  BudgetCreate,
  BudgetUpdate,
  CreateAccountRequest,
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
  UpdateAccountRequest,
} from '@/schema/money';

// ------------------ Refs ------------------
const transactionListRef = ref<InstanceType<typeof TransactionList> | null>(null);
const stackedCardsRef = ref<InstanceType<typeof StackedStatCards> | null>(null);

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

const selectedTransaction = ref<Transaction | null>(null);
const selectedAccount = ref<Account | null>(null);
const selectedBudget = ref<Budget | null>(null);
const selectedReminder = ref<BilReminder | null>(null);

const transactionType = ref<TransactionType>(
  TransactionTypeSchema.enum.Expense,
);

const tabs = [
  { key: 'accounts', label: '账户' },
  { key: 'transactions', label: '交易' },
  { key: 'budgets', label: '预算' },
  { key: 'reminders', label: '提醒' },
];

const accounts = ref<Account[]>([]);
const budgets = ref<Budget[]>([]);
const reminders = ref<BilReminder[]>([]);

const totalAssets = ref(0);
const yearlyIncome = ref(0);
const yearlyExpense = ref(0);
const prevYearlyIncome = ref(0);
const prevYearlyExpense = ref(0);
const monthlyIncome = ref(0);
const monthlyExpense = ref(0);
const prevMonthlyIncome = ref(0);
const prevMonthlyExpense = ref(0);

const budgetRemaining = computed(() =>
  budgets.value
    .filter(b => b.isActive)
    .reduce(
      (sum, b) => sum + (Number.parseFloat(b.amount) - Number.parseFloat(b.usedAmount)),
      0,
    ),
);

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

const finalizeAccountChange = () => finalizeChange(closeAccountModal, [loadAccounts, syncAccountBalanceSummary]);
function finalizeTransactionChange() {
  return finalizeChange(closeTransactionModal, [
    async () => transactionListRef.value?.refresh(),
    loadAccounts,
    syncIncomeExpense,
  ]);
}
const finalizeBudgetChange = () => finalizeChange(closeBudgetModal, [loadBudgets]);
const finalizeReminderChange = () => finalizeChange(closeReminderModal, [loadReminders]);

// ------------------ Load & Sync ------------------
async function loadData() {
  try {
    await Promise.all([loadAccounts(), loadBudgets(), loadReminders(), syncIncomeExpense()]);
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
function showAccountModal() {
  selectedAccount.value = null;
  showAccount.value = true;
}
function editAccount(account: Account) {
  selectedAccount.value = account;
  showAccount.value = true;
}
function closeAccountModal() {
  showAccount.value = false;
  selectedAccount.value = null;
}
async function saveAccount(account: CreateAccountRequest) {
  try {
    await moneyStore.createAccount(account);
    toast.success('添加成功');
    await finalizeAccountChange();
  } catch (err) {
    Lg.e('saveAccount', err);
    toast.error('保存失败');
  }
}
async function updateAccount(serialNum: string, account: UpdateAccountRequest) {
  try {
    if (selectedAccount.value) {
      await moneyStore.updateAccount(serialNum, account);
      toast.success('更新成功');
      await finalizeAccountChange();
    }
  } catch (err) {
    Lg.e('updateAccount', err);
    toast.error('保存失败');
  }
}
async function deleteAccount(serialNum: string) {
  if (await confirmDelete('此账户')) {
    try {
      await moneyStore.deleteAccount(serialNum);
      toast.success('删除成功');
      await finalizeAccountChange();
    } catch (err) {
      Lg.e('deleteAccount', err);
      toast.error('删除失败');
    }
  }
}
async function toggleAccountActive(serialNum: string, isActive: boolean) {
  try {
    await moneyStore.toggleAccountActive(serialNum, isActive);
    toast.success('状态更新成功');
    await finalizeAccountChange();
  } catch (err) {
    Lg.e('toggleAccountActive', err);
    toast.error('状态更新失败');
  }
}

// ------------------ Transaction ------------------
function showTransactionModal(type: TransactionType) {
  transactionType.value = type;
  selectedTransaction.value = null;
  showTransaction.value = true;
}
function editTransaction(transaction: Transaction) {
  selectedTransaction.value = transaction;
  transactionType.value = transaction.transactionType;
  showTransaction.value = true;
}
function closeTransactionModal() {
  showTransaction.value = false;
  selectedTransaction.value = null;
}
async function saveTransaction(transaction: TransactionCreate) {
  try {
    await moneyStore.createTransaction(transaction);
    toast.success('添加成功');
    await finalizeTransactionChange();
  } catch (err) {
    Lg.e('saveTransaction', err);
    toast.error('保存失败');
  }
}
async function updateTransaction(serialNum: string, transaction: TransactionUpdate) {
  try {
    if (selectedTransaction.value) {
      await moneyStore.updateTransaction(serialNum, transaction);
      toast.success('更新成功');
      await finalizeTransactionChange();
    }
  } catch (err) {
    Lg.e('saveTransaction', err);
    toast.error('保存失败');
  }
}
async function deleteTransaction(transaction: Transaction) {
  if (!(await confirmDelete('此交易记录'))) return;
  try {
    if (transaction.category === CategorySchema.enum.Transfer) {
      await moneyStore.deleteTransfer(transaction.serialNum);
      toast.success('转账记录删除成功');
    } else {
      await moneyStore.deleteTransaction(transaction.serialNum);
      toast.success('删除成功');
    }
    await finalizeTransactionChange();
  } catch (err) {
    const error = err as AppError;
    Lg.e('deleteTransaction', err);
    toast.error(error?.message || '删除失败');
  }
}

async function saveTransfer(transfer: TransferCreate) {
  try {
    await moneyStore.createTransfer(transfer);
    toast.success('转账成功');
    await finalizeTransactionChange();
  } catch (err) {
    Lg.e('saveTransfer', err);
    toast.error('转账失败');
  }
}

async function updateTransfer(serialNum: string, transfer: TransferCreate) {
  try {
    await moneyStore.updateTransfer(serialNum, transfer);
    toast.success('转账更新成功');
    await finalizeTransactionChange();
  } catch (err) {
    Lg.e('updateTransfer', err);
    toast.error('转账失败');
  }
}

function viewTransactionDetails(transaction: Transaction) {
  Lg.d('viewTransactionDetails', '查看交易详情:', transaction);
}

// ------------------ Budget ------------------
function showBudgetModal() {
  selectedBudget.value = null;
  showBudget.value = true;
}
function editBudget(budget: Budget) {
  selectedBudget.value = budget;
  showBudget.value = true;
}
function closeBudgetModal() {
  showBudget.value = false;
  selectedBudget.value = null;
}
async function saveBudget(budget: BudgetCreate) {
  try {
    await moneyStore.createBudget(budget);
    toast.success('添加成功');
    await finalizeBudgetChange();
  } catch (err) {
    Lg.e('saveBudget', err);
    toast.error('保存失败');
  }
}
async function updateBudget(serialNum: string, budget: BudgetUpdate) {
  try {
    if (selectedBudget.value) {
      await moneyStore.updateBudget(serialNum, budget);
      toast.success('更新成功');
      await finalizeBudgetChange();
    }
  } catch (err) {
    Lg.e('saveBudget', err);
    toast.error('保存失败');
  }
}
async function deleteBudget(serialNum: string) {
  if (await confirmDelete('此预算')) {
    try {
      await moneyStore.deleteBudget(serialNum);
      toast.success('删除成功');
      await finalizeBudgetChange();
    } catch (err) {
      Lg.e('deleteBudget', err);
      toast.error('删除失败');
    }
  }
}
async function toggleBudgetActive(serialNum: string, isActive: boolean) {
  try {
    await moneyStore.toggleBudgetActive(serialNum, isActive);
    toast.success('状态更新成功');
    await finalizeBudgetChange();
  } catch (err) {
    Lg.e('toggleBudgetActive', err);
    toast.error('状态更新失败');
  }
}

// ------------------ Reminder ------------------
function showReminderModal() {
  selectedReminder.value = null;
  showReminder.value = true;
}
function editReminder(reminder: BilReminder) {
  selectedReminder.value = reminder;
  showReminder.value = true;
}
function closeReminderModal() {
  showReminder.value = false;
  selectedReminder.value = null;
}
async function saveReminder(reminder: BilReminderCreate) {
  try {
    await moneyStore.createReminder(reminder);
    toast.success('添加成功');
    await finalizeReminderChange();
  } catch (err) {
    Lg.e('saveReminder', err);
    toast.error('保存失败');
  }
}
async function updateReminder(serialNum: string, reminder: BilReminderUpdate) {
  try {
    if (selectedReminder.value) {
      await moneyStore.updateReminder(serialNum, reminder);
      toast.success('更新成功');
      await finalizeReminderChange();
    }
  } catch (err) {
    Lg.e('saveReminder', err);
    toast.error('保存失败');
  }
}
async function deleteReminder(serialNum: string) {
  if (await confirmDelete('此提醒')) {
    try {
      await moneyStore.deleteReminder(serialNum);
      toast.success('删除成功');
      await finalizeReminderChange();
    } catch (err) {
      Lg.e('deleteReminder', err);
      toast.error('删除失败');
    }
  }
}
async function markReminderPaid(serialNum: string, isPaid: boolean) {
  try {
    await moneyStore.markReminderPaid(serialNum, isPaid);
    toast.success('标记成功');
    await finalizeReminderChange();
  } catch (err) {
    Lg.e('markReminderPaid', err);
    toast.error('标记失败');
  }
}

// ------------------ Card Events ------------------
function handleCardChange(index: number, card: any) {
  if (hasModalOpen.value) return;
  Lg.d('handleCardChange', '卡片切换:', index, card.title);
}
function handleCardClick(_index: number, _card: any) {
}

onMounted(async () => {
  loadData();
  const currency = await getLocalCurrencyInfo();
  baseCurrency.value = currency.symbol;
});
</script>

<template>
  <div class="mx-auto max-w-1200px p-5">
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

    <div class="overflow-hidden rounded-lg bg-white shadow-[0_2px_4px_rgba(0,0,0,0.1)]">
      <div class="border-b border-gray-200 p-5">
        <div class="mb-3.75 flex flex-wrap items-center justify-between gap-y-3">
          <h3 class="m-0 text-gray-800">
            快捷操作
          </h3>
          <div class="flex flex-wrap justify-end gap-3.75">
            <button
              class="flex items-center gap-2 rounded-md bg-purple-50 px-2 py-3 text-sm text-purple-500 hover:opacity-80"
              @click="showAccountModal"
            >
              <CreditCard class="h-4 w-4" /><span>添加账户</span>
            </button>
            <button
              class="flex items-center gap-2 rounded-md bg-green-50 px-2 py-3 text-sm text-green-600 hover:opacity-80"
              @click="showTransactionModal(TransactionTypeSchema.enum.Income)"
            >
              <PlusCircle class="h-4 w-4" /><span>记录收入</span>
            </button>
            <button
              class="flex items-center gap-2 rounded-md bg-red-50 px-2 py-3 text-sm text-red-500 hover:opacity-80"
              @click="showTransactionModal(TransactionTypeSchema.enum.Expense)"
            >
              <MinusCircle class="h-4 w-4" /><span>记录支出</span>
            </button>
            <button
              class="flex items-center gap-2 rounded-md bg-blue-50 px-2 py-3 text-sm text-blue-500 hover:opacity-80"
              @click="showTransactionModal(TransactionTypeSchema.enum.Transfer)"
            >
              <ArrowRightLeft class="h-4 w-4" /><span>记录转账</span>
            </button>
            <button
              class="flex items-center gap-2 rounded-md bg-orange-50 px-2 py-3 text-sm text-orange-500 hover:opacity-80"
              @click="showBudgetModal"
            >
              <Target class="h-4 w-4" /><span>设置预算</span>
            </button>
            <button
              class="flex items-center gap-2 rounded-md bg-yellow-50 px-2 py-3 text-sm text-yellow-600 hover:opacity-80"
              @click="showReminderModal"
            >
              <Bell class="h-4 w-4" /><span>设置提醒</span>
            </button>
          </div>
        </div>
      </div>

      <div class="flex justify-center overflow-x-auto border-b border-gray-200">
        <button v-for="tab in tabs" :key="tab.key" :class="[activeTab === tab.key ? 'text-blue-600 border-b-[3px] border-blue-600 bg-blue-50 rounded-t-md' : 'text-gray-600']" class="border-b-2 border-transparent px-6 py-3 text-sm font-medium transition-all duration-200" @click="activeTab = tab.key">
          {{ tab.label }}
        </button>
      </div>

      <div class="p-5">
        <AccountList
          v-if="activeTab === 'accounts'"
          :accounts="accounts"
          :loading="accountsLoading"
          @edit="editAccount"
          @delete="deleteAccount"
          @toggle-active="toggleAccountActive"
        />
        <TransactionList
          v-if="activeTab === 'transactions'"
          ref="transactionListRef"
          :accounts="accounts"
          @edit="editTransaction"
          @delete="deleteTransaction"
          @view-details="viewTransactionDetails"
        />
        <BudgetList
          v-if="activeTab === 'budgets'"
          :budgets="budgets"
          :loading="budgetsLoading"
          @edit="editBudget"
          @delete="deleteBudget"
          @toggle-active="toggleBudgetActive"
        />
        <ReminderList
          v-if="activeTab === 'reminders'"
          :reminders="reminders"
          :loading="remindersLoading"
          @edit="editReminder"
          @delete="deleteReminder"
          @mark-paid="markReminderPaid"
        />
      </div>
    </div>

    <TransactionModal
      v-if="showTransaction"
      :type="transactionType"
      :transaction="selectedTransaction"
      :accounts="accounts"
      @close="closeTransactionModal"
      @save="saveTransaction"
      @update="updateTransaction"
      @save-transfer="saveTransfer"
      @update-transfer="updateTransfer"
    />
    <AccountModal
      v-if="showAccount"
      :account="selectedAccount"
      @close="closeAccountModal"
      @save="saveAccount"
      @update="updateAccount"
    />
    <BudgetModal
      v-if="showBudget"
      :budget="selectedBudget"
      @close="closeBudgetModal"
      @save="saveBudget"
      @update="updateBudget"
    />
    <ReminderModal
      v-if="showReminder"
      :reminder="selectedReminder"
      @close="closeReminderModal"
      @save="saveReminder"
      @update="updateReminder"
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

<style lang="postcss">
.main-container { overflow-y: auto; scrollbar-width: none; -ms-overflow-style: none; }
.main-container::-webkit-scrollbar { display: none; }
</style>
