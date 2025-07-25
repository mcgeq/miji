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
import { TransactionTypeSchema } from '@/schema/common';
import { useMoneyStore } from '@/stores/moneyStore';
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
import { formatCurrency, getLocalCurrencyInfo } from '../utils/money';
import type { TransactionType } from '@/schema/common';
import type {
  Account,
  BilReminder,
  Budget,
  TransactionWithAccount,
} from '@/schema/money';

const moneyStore = useMoneyStore();
const { confirmState, confirmDelete, handleConfirm, handleCancel, handleClose } = useConfirm();

const activeTab = ref('accounts');
const baseCurrency = computed(() => getLocalCurrencyInfo().symbol);

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

// 添加对 StackedStatCards 组件的引用
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

// 用于统计的交易数据 - 只获取当月数据用于统计
const monthlyTransactions = ref<TransactionWithAccount[]>([]);

const totalAssets = computed(() => {
  return accounts.value
    .filter(account => account.isActive)
    .reduce((sum, account) => sum + Number.parseFloat(account.balance), 0);
});

const monthlyIncome = computed(() => {
  return monthlyTransactions.value
    .filter(t => t.transactionType === TransactionTypeSchema.enum.Income)
    .reduce((sum, t) => sum + Number.parseFloat(t.amount), 0);
});

const monthlyExpense = computed(() => {
  return monthlyTransactions.value
    .filter(t => t.transactionType === TransactionTypeSchema.enum.Expense)
    .reduce((sum, t) => sum + Number.parseFloat(t.amount), 0);
});

const budgetRemaining = computed(() => {
  return budgets.value
    .filter(b => b.isActive)
    .reduce(
      (sum, b) => sum + (Number.parseFloat(b.amount) - Number.parseFloat(b.usedAmount)),
      0,
    );
});

// 统计卡片数据
const statCards = computed(() => [
  {
    id: 'total-assets',
    title: '总资产',
    value: formatCurrency(totalAssets.value),
    currency: baseCurrency.value,
    icon: 'wallet',
    color: 'primary' as const,
  },
  {
    id: 'monthly-income',
    title: '本月收入',
    value: formatCurrency(monthlyIncome.value),
    currency: baseCurrency.value,
    icon: 'trending-up',
    color: 'success' as const,
  },
  {
    id: 'monthly-expense',
    title: '本月支出',
    value: formatCurrency(monthlyExpense.value),
    currency: baseCurrency.value,
    icon: 'trending-down',
    color: 'danger' as const,
  },
  {
    id: 'budget-remaining',
    title: '预算剩余',
    value: formatCurrency(budgetRemaining.value),
    currency: baseCurrency.value,
    icon: 'target',
    color: 'warning' as const,
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
  }
  else {
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
      loadMonthlyTransactions(),
      loadBudgets(),
      loadReminders(),
    ]);
  }
  catch (err) {
    Lg.e('loadData', err);
    toast.error('加载数据失败');
  }
}

async function loadAccounts() {
  accountsLoading.value = true;
  try {
    accounts.value = await moneyStore.getAccounts();
  }
  finally {
    accountsLoading.value = false;
  }
}

// 只加载当月交易数据用于统计
async function loadMonthlyTransactions() {
  try {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);

    const result = await moneyStore.getTransactions({
      page: 1,
      pageSize: 1000, // 获取足够多的数据用于统计
      dateFrom: startOfMonth.toISOString().split('T')[0],
      dateTo: endOfMonth.toISOString().split('T')[0],
    });
    monthlyTransactions.value = result.items;
  }
  catch (err) {
    Lg.e('loadMonthlyTransactions', '加载月度交易数据失败:', err);
  }
}

async function loadBudgets() {
  budgetsLoading.value = true;
  try {
    budgets.value = await moneyStore.getBudgets();
  }
  finally {
    budgetsLoading.value = false;
  }
}

async function loadReminders() {
  remindersLoading.value = true;
  try {
    reminders.value = await moneyStore.getReminders();
  }
  finally {
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

async function deleteTransaction(serialNum: string) {
  const confirmed = await confirmDelete('此交易记录');
  if (confirmed) {
    try {
      await moneyStore.deleteTransaction(serialNum);
      toast.success('删除成功');
      // 刷新相关数据
      await Promise.all([loadAccounts(), loadMonthlyTransactions()]);
    }
    catch (err) {
      Lg.e('deleteTransaction', err);
      toast.error('删除失败');
    }
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
    }
    else {
      await moneyStore.createTransaction(transaction);
      toast.success('添加成功');
    }
    closeTransactionModal();
    // 刷新相关数据
    await Promise.all([loadAccounts(), loadMonthlyTransactions()]);
  }
  catch (err) {
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
    }
    catch (err) {
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
  }
  catch (err) {
    Lg.e('toggleAccountActive', err);
    toast.error('状态更新失败');
  }
}

function closeAccountModal() {
  showAccount.value = false;
  selectedAccount.value = null;
}

async function saveAccount(account: Account) {
  try {
    if (selectedAccount.value) {
      await moneyStore.updateAccount(account);
      toast.success('更新成功');
    }
    else {
      await moneyStore.createAccount(account);
      toast.success('添加成功');
    }
    closeAccountModal();
    loadAccounts();
  }
  catch (err) {
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
    }
    catch (err) {
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
  }
  catch (err) {
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
    }
    else {
      await moneyStore.createBudget(budget);
      toast.success('添加成功');
    }
    closeBudgetModal();
    loadBudgets();
  }
  catch (err) {
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
    }
    catch (err) {
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
  }
  catch (err) {
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
    }
    else {
      await moneyStore.createReminder(reminder);
      toast.success('添加成功');
    }
    closeReminderModal();
    loadReminders();
  }
  catch (err) {
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
  // 这里可以添加其他需要在卡片切换时执行的逻辑
}

function handleCardClick(_index: number, card: any) {
  // 如果有模态框打开，不执行任何操作
  if (hasModalOpen.value) {
    return;
  }
  Lg.i('MoneyView', card);
  // 可以根据卡片类型执行特定操作
  // switch (card.id) {
  //   case 'total-assets':
  //     activeTab.value = 'accounts';
  //     break;
  //   case 'monthly-income':
  //   case 'monthly-expense':
  //     activeTab.value = 'transactions';
  //     break;
  //   case 'budget-remaining':
  //     activeTab.value = 'budgets';
  //     break;
  // }
}

onMounted(() => {
  loadData();
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
            :accounts="accounts" @edit="editTransaction" @delete="deleteTransaction"
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
      v-if="showTransaction" :type="transactionType" :transaction="selectedTransaction"
      :accounts="accounts" @close="closeTransactionModal" @save="saveTransaction"
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
