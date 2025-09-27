<script setup lang="ts">
import ConfirmModal from '@/components/common/ConfirmModal.vue';
import { useConfirm } from '@/composables/useConfirm';
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
const budgetListRef = ref<InstanceType<typeof BudgetList> | null>(null);
const reminderListRef = ref<InstanceType<typeof ReminderList> | null>(null);
const stackedCardsRef = ref<InstanceType<typeof StackedStatCards> | null>(null);

const moneyStore = useMoneyStore();
const { confirmState, confirmDelete, handleConfirm, handleCancel, handleClose } = useConfirm();

const activeTab = ref('accounts');
const baseCurrency = ref(CURRENCY_CNY.symbol);

const accountsLoading = ref(false);

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

const accounts = ref<Account[]>([]);

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

const finalizeAccountChange = () => finalizeChange(closeAccountModal, [loadAccounts, syncAccountBalanceSummary]);
function finalizeTransactionChange() {
  return finalizeChange(closeTransactionModal, [
    async () => transactionListRef.value?.refresh(),
    loadAccounts,
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
    await Promise.all([loadAccounts(), syncIncomeExpense()]);
  } catch (err) {
    Lg.e('loadData', err);
    toast.error('加载数据失败');
  }
}

async function loadAccounts() {
  accountsLoading.value = true;
  try {
    accounts.value = await moneyStore.getAllAccounts();
  } finally {
    accountsLoading.value = false;
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
    if (transaction.category === 'Transfer' && transaction.relatedTransactionSerialNum) {
      await moneyStore.deleteTransfer(transaction.relatedTransactionSerialNum);
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
          class="tab-btn"
          :class="[activeTab === tab.key ? 'active' : '']"
          @click="activeTab = tab.key"
        >
          {{ tab.label }}
        </button>
      </div>

      <!-- Tab 内容 -->
      <div class="tab-content">
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
          ref="budgetListRef"
          @edit="editBudget"
          @delete="deleteBudget"
          @toggle-active="toggleBudgetActive"
        />
        <ReminderList
          v-if="activeTab === 'reminders'"
          ref="reminderListRef"
          @edit="editReminder"
          @delete="deleteReminder"
          @mark-paid="markReminderPaid"
        />
      </div>
    </div>

    <!-- Modals -->
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

/* Tabs */
.tabs {
  display: flex;
  overflow-x: auto;
  border: 1px solid var(--color-base-300);
  justify-content: center;
  background-color: var(--color-base-100);
}

.tab-btn {
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

.tab-btn.active {
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
