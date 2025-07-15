<template>
  <div class="p-5 max-w-1200px mx-auto">
    <!-- 头部统计卡片 -->
    <div class="grid grid-cols-[repeat(auto-fit,minmax(250px,1fr))] gap-5 mb-7.5">
      <StatCard title="总资产" :value="formatCurrency(totalAssets)" :currency="baseCurrency" icon="wallet"
        color="primary" />
      <StatCard title="本月收入" :value="formatCurrency(monthlyIncome)" :currency="baseCurrency" icon="trending-up"
        color="success" />
      <StatCard title="本月支出" :value="formatCurrency(monthlyExpense)" :currency="baseCurrency" icon="trending-down"
        color="danger" />
      <StatCard title="预算剩余" :value="formatCurrency(budgetRemaining)" :currency="baseCurrency" icon="target"
        color="warning" />
    </div>

    <!-- 主要功能区域 -->
    <div class="bg-white rounded-lg shadow-[0_2px_4px_rgba(0,0,0,0.1)] overflow-hidden">
      <!-- 快速操作 -->
      <div class="p-5 border-b border-gray-200">
        <div class="flex justify-between items-center mb-3.75 flex-wrap gap-y-3">
          <!-- 快捷操作标题靠左 -->
          <h3 class="text-gray-800 m-0">快捷操作</h3>
          <!-- 操作按钮靠右 -->
          <div class="flex gap-3.75 flex-wrap justify-end">
            <button
              class="flex items-center gap-2 px-2 py-3 border-none rounded-md cursor-pointer text-sm transition-all duration-200 bg-purple-50 text-purple-500 hover:opacity-80 hover:-translate-y-0.25"
              @click="showAccountModal">
              <CreditCard class="w-4 h-4" />
              <span>添加账户</span>
            </button>
            <button
              class="flex items-center gap-2 px-2 py-3 border-none rounded-md cursor-pointer text-sm transition-all duration-200 bg-green-50 text-green-600 hover:opacity-80 hover:-translate-y-0.25"
              @click="showTransactionModal(TransactionTypeSchema.enum.Income)">
              <PlusCircle class="w-4 h-4" />
              <span>记录收入</span>
            </button>
            <button
              class="flex items-center gap-2 px-2 py-3 border-none rounded-md cursor-pointer text-sm transition-all duration-200 bg-red-50 text-red-500 hover:opacity-80 hover:-translate-y-0.25"
              @click="showTransactionModal(TransactionTypeSchema.enum.Expense)">
              <MinusCircle class="w-4 h-4" />
              <span>记录支出</span>
            </button>
            <button
              class="flex items-center gap-2 px-2 py-3 border-none rounded-md cursor-pointer text-sm transition-all duration-200 bg-blue-50 text-blue-500 hover:opacity-80 hover:-translate-y-0.25"
              @click="showTransactionModal(TransactionTypeSchema.enum.Transfer)">
              <ArrowRightLeft class="w-4 h-4" />
              <span>记录转账</span>
            </button>
            <button
              class="flex items-center gap-2 px-2 py-3 border-none rounded-md cursor-pointer text-sm transition-all duration-200 bg-orange-50 text-orange-500 hover:opacity-80 hover:-translate-y-0.25"
              @click="showBudgetModal">
              <Target class="w-4 h-4" />
              <span>设置预算</span>
            </button>
            <button
              class="flex items-center gap-2 px-2 py-3 border-none rounded-md cursor-pointer text-sm transition-all duration-200 bg-yellow-50 text-yellow-600 hover:opacity-80 hover:-translate-y-0.25"
              @click="showReminderModal">
              <Bell class="w-4 h-4" />
              <span>设置提醒</span>
            </button>
          </div>
        </div>
      </div>
      <!-- 标签页切换 -->
      <div class="flex justify-center border-b border-gray-200 overflow-x-auto">
        <button v-for="tab in tabs" :key="tab.key" @click="activeTab = tab.key" :class="[
          'px-6 py-3 text-sm font-medium border-b-2 border-transparent text-gray-600 hover:text-blue-500 hover:border-blue-300 transition-all duration-200',
          activeTab === tab.key && 'text-blue-600 border-b-[3px] border-blue-600 bg-blue-50 rounded-t-md'
        ]">
          {{ tab.label }}
        </button>
      </div>

      <!-- 内容区域 -->
      <div class="p-5">
        <!-- 账户管理 -->
        <div v-if="activeTab === 'accounts'" class="accounts-section">
          <AccountList :accounts="accounts" :loading="accountsLoading" @edit="editAccount" @delete="deleteAccount"
            @toggle-active="toggleAccountActive" />
        </div>

        <!-- 交易记录 -->
        <div v-if="activeTab === 'transactions'" class="transactions-section">
          <div class="flex justify-end items-center mb-5">
            <div class="flex gap-2.5 flex-wrap">
              <select v-model="transactionFilters.type" class="p-2 border border-gray-300 rounded-md text-sm">
                <option value="">全部类型</option>
                <option value="income">收入</option>
                <option value="expense">支出</option>
                <option value="transfer">转账</option>
              </select>
              <select v-model="transactionFilters.account" class="p-2 border border-gray-300 rounded-md text-sm">
                <option value="">全部账户</option>
                <option v-for="account in accounts" :key="account.serialNum" :value="account.serialNum">
                  {{ account.name }}
                </option>
              </select>
              <input type="date" v-model="transactionFilters.dateFrom" placeholder="开始日期"
                class="p-2 border border-gray-300 rounded-md text-sm" />
              <input type="date" v-model="transactionFilters.dateTo" placeholder="结束日期"
                class="p-2 border border-gray-300 rounded-md text-sm" />
            </div>
          </div>
          <TransactionList :transactions="filteredTransactions" :loading="transactionsLoading" @edit="editTransaction"
            @delete="deleteTransaction" @view-details="viewTransactionDetails" />
          <SimplePagination :current-page="transactionPagination.currentPage"
            :total-pages="transactionPagination.totalPages" :total-items="transactionPagination.totalItems"
            :page-size="transactionPagination.pageSize" :show-page-size="false" :page-size-options="[10, 20, 50, 100]"
            @page-change="handleTransactionPageChange" @page-size-change="handleTransactionPageSizeChange" />
        </div>

        <!-- 预算管理 -->
        <div v-if="activeTab === 'budgets'" class="budgets-section">
          <BudgetList :budgets="budgets" :loading="budgetsLoading" @edit="editBudget" @delete="deleteBudget"
            @toggle-active="toggleBudgetActive" />
        </div>

        <!-- 账单提醒 -->
        <div v-if="activeTab === 'reminders'" class="reminders-section">
          <ReminderList :reminders="reminders" :loading="remindersLoading" @edit="editReminder" @delete="deleteReminder"
            @mark-paid="markReminderPaid" />
        </div>
      </div>
    </div>

    <!-- 模态框 -->
    <TransactionModal v-if="showTransaction" :type="transactionType"
      :transaction="selectedTransaction" :accounts="accounts" @close="closeTransactionModal" @save="saveTransaction" />

    <AccountModal v-if="showAccount" :account="selectedAccount" @close="closeAccountModal"
      @save="saveAccount" />

    <BudgetModal v-if="showBudget" :budget="selectedBudget" @close="closeBudgetModal"
      @save="saveBudget" />

    <ReminderModal v-if="showReminder" :reminder="selectedReminder" @close="closeReminderModal"
      @save="saveReminder" />
  </div>
</template>

<script setup lang="ts">
import {
  PlusCircle,
  MinusCircle,
  ArrowRightLeft,
  Target,
  CreditCard,
  Bell,
} from 'lucide-vue-next';
import StatCard from '../components/StatCard.vue';
import AccountList from '../components/AccountList.vue';
import AccountModal from '../components/AccountModal.vue';
import TransactionList from '../components/TransactionList.vue';
import BudgetList from '../components/BudgetList.vue';
import BudgetModal from '../components/BudgetModal.vue';
import ReminderList from '../components/ReminderList.vue';
import ReminderModal from '../components/ReminderModal.vue';
import TransactionModal from '../components/TransactionModal.vue';
import { useMoneyStore } from '@/stores/moneyStore';
import SimplePagination from '@/components/common/SimplePagination.vue';
import {
  Account,
  BilReminder,
  Budget,
  TransactionWithAccount,
} from '@/schema/money';
import { TransactionType, TransactionTypeSchema } from '@/schema/common';
import { toast } from '@/utils/toast';
import { formatCurrency, getLocalCurrencyInfo } from '../utils/money';

const moneyStore = useMoneyStore();

const activeTab = ref('accounts');
const baseCurrency = computed(() => getLocalCurrencyInfo().symbol);

const accountsLoading = ref(false);
const transactionsLoading = ref(false);
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

const transactionFilters = ref({
  type: '',
  account: '',
  dateFrom: '',
  dateTo: '',
});

const transactionPagination = ref({
  currentPage: 1,
  totalPages: 1,
  totalItems: 0,
  pageSize: 20,
});

const tabs = [
  { key: 'accounts', label: '账户' },
  { key: 'transactions', label: '交易' },
  { key: 'budgets', label: '预算' },
  { key: 'reminders', label: '提醒' },
];

const accounts = ref<Account[]>([]);
const transactions = ref<TransactionWithAccount[]>([]);
const budgets = ref<Budget[]>([]);
const reminders = ref<BilReminder[]>([]);

const totalAssets = computed(() => {
  return accounts.value
    .filter((account) => account.isActive)
    .reduce((sum, account) => sum + parseFloat(account.balance), 0);
});

const monthlyIncome = computed(() => {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);

  return transactions.value
    .filter((t) => {
      const date = new Date(t.date);
      return (
        t.transactionType === TransactionTypeSchema.enum.Income &&
        date >= startOfMonth &&
        date <= endOfMonth
      );
    })
    .reduce((sum, t) => sum + parseFloat(t.amount), 0);
});

const monthlyExpense = computed(() => {
  const now = new Date();
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
  const endOfMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0);

  return transactions.value
    .filter((t) => {
      const date = new Date(t.date);
      return (
        t.transactionType === TransactionTypeSchema.enum.Expense &&
        date >= startOfMonth &&
        date <= endOfMonth
      );
    })
    .reduce((sum, t) => sum + parseFloat(t.amount), 0);
});

const budgetRemaining = computed(() => {
  return budgets.value
    .filter((b) => b.isActive)
    .reduce(
      (sum, b) => sum + (parseFloat(b.amount) - parseFloat(b.usedAmount)),
      0,
    );
});

const filteredTransactions = computed(() => {
  let filtered = [...transactions.value];

  if (transactionFilters.value.type) {
    filtered = filtered.filter(
      (t) => t.transactionType === transactionFilters.value.type,
    );
  }

  if (transactionFilters.value.account) {
    filtered = filtered.filter(
      (t) => t.accountSerialNum === transactionFilters.value.account,
    );
  }

  if (transactionFilters.value.dateFrom) {
    filtered = filtered.filter(
      (t) => t.date >= transactionFilters.value.dateFrom,
    );
  }

  if (transactionFilters.value.dateTo) {
    filtered = filtered.filter(
      (t) => t.date <= transactionFilters.value.dateTo,
    );
  }

  return filtered;
});

const loadData = async () => {
  try {
    await Promise.all([
      loadAccounts(),
      loadTransactions(),
      loadBudgets(),
      loadReminders(),
    ]);
  } catch (error) {
    toast.error('加载数据失败');
  }
};

const loadAccounts = async () => {
  accountsLoading.value = true;
  try {
    accounts.value = await moneyStore.getAccounts();
  } finally {
    accountsLoading.value = false;
  }
};

const loadTransactions = async () => {
  transactionsLoading.value = true;
  try {
    const result = await moneyStore.getTransactions({
      page: transactionPagination.value.currentPage,
      pageSize: transactionPagination.value.pageSize,
    });
    transactions.value = result.items;
    transactionPagination.value.totalItems = result.total;
    transactionPagination.value.totalPages = Math.ceil(
      result.total / transactionPagination.value.pageSize,
    );
  } finally {
    transactionsLoading.value = false;
  }
};

const loadBudgets = async () => {
  budgetsLoading.value = true;
  try {
    budgets.value = await moneyStore.getBudgets();
  } finally {
    budgetsLoading.value = false;
  }
};

const loadReminders = async () => {
  remindersLoading.value = true;
  try {
    reminders.value = await moneyStore.getReminders();
  } finally {
    remindersLoading.value = false;
  }
};

const showTransactionModal = (type: TransactionType) => {
  transactionType.value = type;
  selectedTransaction.value = null;
  showTransaction.value = true;
};

const editTransaction = (transaction: TransactionWithAccount) => {
  selectedTransaction.value = transaction;
  transactionType.value = transaction.transactionType;
  showTransaction.value = true;
};

const deleteTransaction = async (serialNum: string) => {
  if (confirm('确定删除此交易记录吗？')) {
    try {
      await moneyStore.deleteTransaction(serialNum);
      toast.success('删除成功');
      loadTransactions();
    } catch (error) {
      toast.error('删除失败');
    }
  }
};

const viewTransactionDetails = (transaction: TransactionWithAccount) => {
  console.log('查看交易详情:', transaction);
};

const closeTransactionModal = () => {
  showTransaction.value = false;
  selectedTransaction.value = null;
};

const saveTransaction = async (transaction: TransactionWithAccount) => {
  try {
    if (selectedTransaction.value) {
      await moneyStore.updateTransaction(transaction);
      toast.success('更新成功');
    } else {
      await moneyStore.createTransaction(transaction);
      toast.success('添加成功');
    }
    closeTransactionModal();
    loadTransactions();
    loadAccounts();
  } catch (error) {
    toast.error('保存失败');
  }
};

const showAccountModal = () => {
  selectedAccount.value = null;
  showAccount.value = true;
};

const editAccount = (account: Account) => {
  selectedAccount.value = account;
  showAccount.value = true;
};

const deleteAccount = async (serialNum: string) => {
  if (confirm('确定删除此账户吗？')) {
    try {
      await moneyStore.deleteAccount(serialNum);
      toast.success('删除成功');
      loadAccounts();
    } catch (error) {
      toast.error('删除失败');
    }
  }
};

const toggleAccountActive = async (serialNum: string) => {
  try {
    await moneyStore.toggleAccountActive(serialNum);
    toast.success('状态更新成功');
    loadAccounts();
  } catch (error) {
    toast.error('状态更新失败');
  }
};

const closeAccountModal = () => {
  showAccount.value = false;
  selectedAccount.value = null;
};

const saveAccount = async (account: Account) => {
  try {
    if (selectedAccount.value) {
      await moneyStore.updateAccount(account);
      toast.success('更新成功');
    } else {
      await moneyStore.createAccount(account);
      toast.success('添加成功');
    }
    closeAccountModal();
    loadAccounts();
  } catch (error) {
    toast.error('保存失败');
  }
};

const showBudgetModal = () => {
  selectedBudget.value = null;
  showBudget.value = true;
};

const editBudget = (budget: Budget) => {
  selectedBudget.value = budget;
  showBudget.value = true;
};

const deleteBudget = async (serialNum: string) => {
  if (confirm('确定删除此预算吗？')) {
    try {
      await moneyStore.deleteBudget(serialNum);
      toast.success('删除成功');
      loadBudgets();
    } catch (error) {
      toast.error('删除失败');
    }
  }
};

const toggleBudgetActive = async (serialNum: string) => {
  try {
    await moneyStore.toggleBudgetActive(serialNum);
    toast.success('状态更新成功');
    loadBudgets();
  } catch (error) {
    toast.error('状态更新失败');
  }
};

const closeBudgetModal = () => {
  showBudget.value = false;
  selectedBudget.value = null;
};

const saveBudget = async (budget: Budget) => {
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
  } catch (error) {
    toast.error('保存失败');
  }
};

const showReminderModal = () => {
  selectedReminder.value = null;
  showReminder.value = true;
};

const editReminder = (reminder: BilReminder) => {
  selectedReminder.value = reminder;
  showReminder.value = true;
};

const deleteReminder = async (serialNum: string) => {
  if (confirm('确定删除此提醒吗？')) {
    try {
      await moneyStore.deleteReminder(serialNum);
      toast.success('删除成功');
      loadReminders();
    } catch (error) {
      toast.error('删除失败');
    }
  }
};

const markReminderPaid = async (serialNum: string) => {
  try {
    await moneyStore.markReminderPaid(serialNum);
    toast.success('标记成功');
    loadReminders();
  } catch (error) {
    toast.error('标记失败');
  }
};

const closeReminderModal = () => {
  showReminder.value = false;
  selectedReminder.value = null;
};

const saveReminder = async (reminder: BilReminder) => {
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
  } catch (error) {
    toast.error('保存失败');
  }
};

const handleTransactionPageChange = (page: number) => {
  transactionPagination.value.currentPage = page;
  loadTransactions();
};

const handleTransactionPageSizeChange = (pageSize: number) => {
  transactionPagination.value.pageSize = pageSize;
  transactionPagination.value.currentPage = 1; // 重置到第一页
  // 如果需要，可以在这里调用 API 获取新数据
  // await fetchTransactions(1, pageSize);
};

// 计算是否有 Modal 打开
const hasModalOpen = computed(() => {
  return (
    showTransaction.value ||
    showAccount.value ||
    showBudget.value ||
    showReminder.value
  );
});

// 监听并控制背景滚动
watchEffect(() => {
  if (hasModalOpen.value) {
    const scrollY = window.scrollY;
    document.body.style.overflow = 'hidden';
    document.body.style.position = 'fixed';
    document.body.style.top = `-${scrollY}px`;
    document.body.style.width = '100%';
  } else {
    const scrollY = document.body.style.top;
    document.body.style.overflow = '';
    document.body.style.position = '';
    document.body.style.top = '';
    document.body.style.width = '';
    if (scrollY) {
      window.scrollTo(0, parseInt(scrollY || '0') * -1);
    }
  }
});

watch(
  transactionFilters,
  () => {
    transactionPagination.value.currentPage = 1;
    loadTransactions();
  },
  { deep: true },
);

onMounted(() => {
  loadData();
});
</script>

<style lang="postcss">
.btn-div {
  @apply flex justify-end items-center mb-3;
}

.btn {
  @apply flex items-center gap-1 px-3 py-1.5 border-none rounded-md cursor-pointer text-xs bg-[#1890ff] text-white transition-all duration-200 hover:bg-[#40a9ff]
}

/* 新增：隐藏滚动条 */
html, body {
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE 和 Edge */
}

html::-webkit-scrollbar, body::-webkit-scrollbar {
  display: none; /* Chrome, Safari, Opera */
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
