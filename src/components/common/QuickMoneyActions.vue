<script setup lang="ts">
import ConfirmModal from '@/components/common/ConfirmModal.vue';
import { useConfirm } from '@/composables/useConfirm';
import AccountModal from '@/features/money/components/AccountModal.vue';
import BudgetModal from '@/features/money/components/BudgetModal.vue';
import ReminderModal from '@/features/money/components/ReminderModal.vue';
import TransactionModal from '@/features/money/components/TransactionModal.vue';
import { formatCurrency } from '@/features/money/utils/money';
import { TransactionTypeSchema } from '@/schema/common';
import { lowercaseFirstLetter } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
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

// Props
interface Props {
  showAmountToggle?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  showAmountToggle: false,
});

const { t } = useI18n();
const moneyStore = useMoneyStore();
const { confirmState, handleConfirm, handleCancel, handleClose } = useConfirm();

const showTransaction = ref(false);
const showAccount = ref(false);
const showBudget = ref(false);
const showReminder = ref(false);
const showKeyboardHelp = ref(false);

const selectedTransaction = ref<Transaction | null>(null);
const selectedAccount = ref<Account | null>(null);
const selectedBudget = ref<Budget | null>(null);
const selectedReminder = ref<BilReminder | null>(null);

const transactionType = ref<TransactionType>(TransactionTypeSchema.enum.Expense);
const accounts = ref<Account[]>([]);

// 标签切换
type TabType = 'accounts' | 'transactions' | 'budgets' | 'reminders';
const activeTab = ref<TabType>('accounts');
const transactions = ref<Transaction[]>([]);
const budgets = ref<Budget[]>([]);
const reminders = ref<BilReminder[]>([]);

// ------------------ Transaction ------------------
function showTransactionModal(type: TransactionType) {
  transactionType.value = type;
  selectedTransaction.value = null;
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
    closeTransactionModal();
    await loadTransactions();
    await loadAccounts();
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
      closeTransactionModal();
      await loadTransactions();
      await loadAccounts();
    }
  } catch (err) {
    Lg.e('updateTransaction', err);
    toast.error('保存失败');
  }
}

async function saveTransfer(transfer: TransferCreate) {
  try {
    await moneyStore.createTransfer(transfer);
    toast.success('转账成功');
    closeTransactionModal();
    await loadTransactions();
    await loadAccounts();
  } catch (err) {
    Lg.e('saveTransfer', err);
    toast.error('转账失败');
  }
}

async function updateTransfer(serialNum: string, transfer: TransferCreate) {
  try {
    await moneyStore.updateTransfer(serialNum, transfer);
    toast.success('转账更新成功');
    closeTransactionModal();
    await loadTransactions();
    await loadAccounts();
  } catch (err) {
    Lg.e('updateTransfer', err);
    toast.error('转账失败');
  }
}

// ------------------ Account ------------------
function showAccountModal() {
  selectedAccount.value = null;
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
    closeAccountModal();
    await loadAccounts();
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
      closeAccountModal();
      await loadAccounts();
    }
  } catch (err) {
    Lg.e('updateAccount', err);
    toast.error('保存失败');
  }
}

// ------------------ Budget ------------------
function showBudgetModal() {
  selectedBudget.value = null;
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
    closeBudgetModal();
    await loadBudgets();
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
      closeBudgetModal();
      await loadBudgets();
    }
  } catch (err) {
    Lg.e('updateBudget', err);
    toast.error('保存失败');
  }
}

// ------------------ Reminder ------------------
function showReminderModal() {
  selectedReminder.value = null;
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
    closeReminderModal();
    await loadReminders();
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
      closeReminderModal();
      await loadReminders();
    }
  } catch (err) {
    Lg.e('updateReminder', err);
    toast.error('保存失败');
  }
}

async function loadAccounts() {
  try {
    accounts.value = await moneyStore.getAllAccounts();
  } catch (err) {
    Lg.e('loadAccounts', err);
  }
}

async function loadTransactions() {
  try {
    const allTransactions = await moneyStore.getAllTransactions();
    transactions.value = allTransactions.slice(0, 10);
  } catch (err) {
    Lg.e('loadTransactions', err);
  }
}

async function loadBudgets() {
  try {
    budgets.value = moneyStore.budgetsPaged.rows;
    if (budgets.value.length === 0) {
      await moneyStore.updateBudgets(true);
      budgets.value = moneyStore.budgetsPaged.rows;
    }
  } catch (err) {
    Lg.e('loadBudgets', err);
  }
}

async function loadReminders() {
  try {
    reminders.value = await moneyStore.getAllReminders();
  } catch (err) {
    Lg.e('loadReminders', err);
  }
}

function switchTab(tab: TabType) {
  activeTab.value = tab;
  switch (tab) {
    case 'accounts':
      loadAccounts();
      break;
    case 'transactions':
      loadTransactions();
      break;
    case 'budgets':
      loadBudgets();
      break;
    case 'reminders':
      loadReminders();
      break;
  }
}

// 键盘快捷键：
const keyboardShortcuts = [
  { key: 'A', label: '添加账户', action: 'showAccountModal' },
  { key: 'I', label: '记录收入', action: 'showIncomeModal' },
  { key: 'E', label: '记录支出', action: 'showExpenseModal' },
  { key: 'T', label: '记录转账', action: 'showTransferModal' },
  { key: 'B', label: '设置预算', action: 'showBudgetModal' },
  { key: 'R', label: '设置提醒', action: 'showReminderModal' },
  { key: '?', label: '显示帮助', action: 'toggleHelp' },
];

function handleKeyPress(event: KeyboardEvent) {
  // 如果任何模态框已打开，只处理 ESC 键
  const anyModalOpen = showTransaction.value || showAccount.value || showBudget.value || showReminder.value;
  if (anyModalOpen) {
    if (event.key === 'Escape') {
      event.preventDefault();
      closeAllModals();
    }
    return;
  }
  // 排除在输入框中的情况
  const target = event.target as HTMLElement;
  if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
    return;
  }

  const key = event.key.toUpperCase();

  switch (key) {
    case 'A':
      event.preventDefault();
      showAccountModal();
      break;
    case 'I':
      event.preventDefault();
      showTransactionModal(TransactionTypeSchema.enum.Income);
      break;
    case 'E':
      event.preventDefault();
      showTransactionModal(TransactionTypeSchema.enum.Expense);
      break;
    case 'T':
      event.preventDefault();
      showTransactionModal(TransactionTypeSchema.enum.Transfer);
      break;
    case 'B':
      event.preventDefault();
      showBudgetModal();
      break;
    case 'R':
      event.preventDefault();
      showReminderModal();
      break;
    case '?':
      event.preventDefault();
      showKeyboardHelp.value = !showKeyboardHelp.value;
      break;
  }
}

function closeAllModals() {
  closeTransactionModal();
  closeAccountModal();
  closeBudgetModal();
  closeReminderModal();
}

// 切换金额可见性
function toggleAmountVisibility() {
  moneyStore.toggleGlobalAmountVisibility();
}

onMounted(async () => {
  await loadAccounts();
  await moneyStore.getAllCategories();
  await moneyStore.getAllSubCategories();
  window.addEventListener('keydown', handleKeyPress);
  // 初始加载所有数据
  await loadTransactions();
  await loadBudgets();
  await loadReminders();
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyPress);
});
</script>

<template>
  <div class="qm-quick-money-container">
    <!-- 快捷键帮助提示 - 左上角 -->
    <div class="qm-keyboard-help" :class="{ show: showKeyboardHelp }">
      <div class="qm-help-header">
        <h4>快捷键</h4>
        <button class="qm-close-btn" @click="showKeyboardHelp = false">
          <LucideX :size="16" />
        </button>
      </div>
      <div class="qm-shortcuts-list">
        <div v-for="shortcut in keyboardShortcuts" :key="shortcut.key" class="qm-shortcut-item">
          <kbd class="qm-shortcut-key">{{ shortcut.key }}</kbd>
          <span class="qm-shortcut-label">{{ shortcut.label }}</span>
        </div>
      </div>
    </div>

    <!-- 快捷键提示按钮 - 右上角 -->
    <button class="qm-help-toggle" title="快捷键帮助 (?)" @click="showKeyboardHelp = !showKeyboardHelp">
      <LucideKeyboard :size="20" />
    </button>

    <div class="qm-quick-actions">
      <button class="qm-btn qm-btn-purple" title="添加账户" @click="showAccountModal">
        <LucideCreditCard :size="12" />
      </button>
      <button class="qm-btn qm-btn-green" title="记录收入" @click="showTransactionModal(TransactionTypeSchema.enum.Income)">
        <LucidePlusCircle :size="12" />
      </button>
      <button class="qm-btn qm-btn-red" title="记录支出" @click="showTransactionModal(TransactionTypeSchema.enum.Expense)">
        <LucideMinusCircle :size="12" />
      </button>
      <button class="qm-btn qm-btn-blue" title="记录转账" @click="showTransactionModal(TransactionTypeSchema.enum.Transfer)">
        <LucideArrowRightLeft :size="12" />
      </button>
      <button class="qm-btn qm-btn-orange" title="设置预算" @click="showBudgetModal">
        <LucideTarget :size="12" />
      </button>
      <button class="qm-btn qm-btn-yellow" title="设置提醒" @click="showReminderModal">
        <LucideBell :size="12" />
      </button>
      <!-- 隐藏金额按钮 -->
      <button
        v-if="props.showAmountToggle"
        class="qm-btn"
        :class="moneyStore.globalAmountHidden ? 'qm-btn-gray' : 'qm-btn-blue'"
        :title="moneyStore.globalAmountHidden ? '显示金额' : '隐藏金额'"
        @click="toggleAmountVisibility"
      >
        <LucideEye v-if="!moneyStore.globalAmountHidden" :size="12" />
        <LucideEyeOff v-else :size="12" />
      </button>
    </div>

    <!-- 标签切换 -->
    <div class="qm-tabs-container">
      <button
        class="qm-tab-btn"
        :class="{ active: activeTab === 'accounts' }"
        @click="switchTab('accounts')"
      >
        账户
      </button>
      <button
        class="qm-tab-btn"
        :class="{ active: activeTab === 'transactions' }"
        @click="switchTab('transactions')"
      >
        交易
      </button>
      <button
        class="qm-tab-btn"
        :class="{ active: activeTab === 'budgets' }"
        @click="switchTab('budgets')"
      >
        预算
      </button>
      <button
        class="qm-tab-btn"
        :class="{ active: activeTab === 'reminders' }"
        @click="switchTab('reminders')"
      >
        提醒
      </button>
    </div>

    <!-- 列表内容 -->
    <div class="qm-list-container">
      <!-- 账户列表 -->
      <div v-if="activeTab === 'accounts'" class="qm-list-content">
        <div v-if="accounts.length === 0" class="qm-empty-state">
          暂无账户
        </div>
        <div v-else class="qm-list-items">
          <div v-for="account in accounts" :key="account.serialNum" class="qm-list-item">
            <div class="qm-item-icon" :style="{ backgroundColor: account.color }">
              <LucideCreditCard :size="16" />
            </div>
            <div class="qm-item-content">
              <div class="qm-item-name">
                {{ account.name }}
              </div>
              <div class="qm-item-desc">
                {{ account.type }}
              </div>
            </div>
            <div class="qm-item-value">
              {{ moneyStore.globalAmountHidden ? '***' : formatCurrency(account.balance ?? 0) }}
            </div>
          </div>
        </div>
      </div>

      <!-- 交易列表 -->
      <div v-if="activeTab === 'transactions'" class="qm-list-content">
        <div v-if="transactions.length === 0" class="qm-empty-state">
          暂无交易
        </div>
        <div v-else class="qm-list-items">
          <div v-for="transaction in transactions" :key="transaction.serialNum" class="qm-list-item">
            <div class="qm-item-icon" :class="`qm-icon-${transaction.transactionType.toLowerCase()}`">
              <LucidePlusCircle v-if="transaction.transactionType === 'Income'" :size="16" />
              <LucideMinusCircle v-else-if="transaction.transactionType === 'Expense'" :size="16" />
              <LucideArrowRightLeft v-else :size="16" />
            </div>
            <div class="qm-item-content">
              <div class="qm-item-name">
                {{ transaction.description }}
              </div>
              <div class="qm-item-desc">
                {{ t(`common.categories.${lowercaseFirstLetter(transaction.category)}`) }}<template v-if="transaction.subCategory">
                  -{{ t(`common.subCategories.${lowercaseFirstLetter(transaction.subCategory)}`) }}
                </template>
              </div>
            </div>
            <div class="qm-item-value-wrapper">
              <div class="qm-item-value" :class="`value-${transaction.transactionType.toLowerCase()}`">
                {{ transaction.transactionType === 'Income' ? '+' : '-' }}{{ formatCurrency(transaction.amount ?? 0) }}
              </div>
              <div class="qm-item-date">
                {{ DateUtils.formatDateTime(transaction.date) }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 预算列表 -->
      <div v-if="activeTab === 'budgets'" class="qm-list-content">
        <div v-if="budgets.length === 0" class="qm-empty-state">
          暂无预算
        </div>
        <div v-else class="qm-list-items">
          <div v-for="budget in budgets" :key="budget.serialNum" class="qm-list-item">
            <div class="item-icon icon-budget">
              <LucideTarget :size="16" />
            </div>
            <div class="qm-item-content">
              <div class="qm-item-name">
                {{ budget.name }}
              </div>
              <div class="qm-item-desc">
                {{ budget.description }}
              </div>
            </div>
            <div class="qm-item-value">
              {{ formatCurrency(budget.amount ?? 0) }}
            </div>
          </div>
        </div>
      </div>

      <!-- 提醒列表 -->
      <div v-if="activeTab === 'reminders'" class="qm-list-content">
        <div v-if="reminders.length === 0" class="qm-empty-state">
          暂无提醒
        </div>
        <div v-else class="qm-list-items">
          <div v-for="reminder in reminders" :key="reminder.serialNum" class="qm-list-item">
            <div class="item-icon icon-reminder">
              <LucideBell :size="16" />
            </div>
            <div class="qm-item-content">
              <div class="qm-item-name">
                {{ reminder.name }}
              </div>
              <div class="qm-item-desc">
                {{ reminder.billDate }}
              </div>
            </div>
            <div class="qm-item-value">
              {{ formatCurrency(reminder.amount ?? 0) }}
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modals - 使用 Teleport 传送到 body，确保覆盖整个页面 -->
    <Teleport to="body">
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
    </Teleport>
  </div>
</template>

<style scoped>
.qm-quick-money-container {
  width: 100%;
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  height: 100%;
  padding: 1rem;
  padding-top: 1rem;
  overflow: hidden;
  box-sizing: border-box;
}

/* 快捷键帮助提示框 - 左上角 */
.qm-keyboard-help {
  position: absolute;
  top: 0.5rem;
  left: 0.5rem;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  padding: 0.75rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  z-index: 100;
  opacity: 0;
  transform: translateY(-10px);
  pointer-events: none;
  transition: all 0.2s ease;
  max-width: 200px;
}

.qm-keyboard-help.show {
  opacity: 1;
  transform: translateY(0);
  pointer-events: auto;
}

.qm-help-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--color-base-300);
}

.qm-help-header h4 {
  margin: 0;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.qm-close-btn {
  padding: 0.25rem;
  background: transparent;
  border: none;
  cursor: pointer;
  color: var(--color-base-content);
  opacity: 0.6;
  transition: opacity 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.qm-close-btn:hover {
  opacity: 1;
}

.qm-shortcuts-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.qm-shortcut-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
}

.qm-shortcut-key {
  min-width: 1.5rem;
  padding: 0.125rem 0.375rem;
  font-size: 0.75rem;
  font-weight: 600;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  color: var(--color-base-content);
  background-color: var(--color-base-200);
  border: 1px solid var(--color-base-300);
  border-radius: 0.25rem;
  text-align: center;
}

.qm-shortcut-label {
  color: var(--color-base-content);
}

/* 快捷键帮助按钮 - 右上角 */
.qm-help-toggle {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  padding: 0.5rem;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-base-content);
  opacity: 0.7;
  z-index: 10;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.qm-help-toggle:hover {
  opacity: 1;
  background-color: var(--color-base-200);
  transform: scale(1.05);
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
}

.qm-quick-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  width: 100%;
  align-items: center;
  justify-content: center;
  margin-bottom: 1rem;
}

/* 标签切换 */
.qm-tabs-container {
  display: flex;
  gap: 0.25rem;
  width: 100%;
  border-bottom: 2px solid var(--color-base-300);
  margin-bottom: 0.75rem;
}

.qm-tab-btn {
  flex: 1;
  padding: 0.2rem;
  background: transparent;
  border: none;
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
  opacity: 0.6;
  transition: all 0.2s;
  position: relative;
  border-radius: 0.25rem 0.25rem 0 0;
}

.qm-tab-btn:hover {
  opacity: 1;
  background-color: var(--color-base-200);
}

.qm-tab-btn.active {
  opacity: 1;
  color: var(--color-neutral);
  font-weight: 600;
}

.qm-tab-btn.active::after {
  content: '';
  position: absolute;
  bottom: -2px;
  left: 0;
  right: 0;
  height: 2px;
  background-color: var(--color-neutral);
}

/* 列表容器 */
.qm-list-container {
  width: 100%;
  flex: 1;
  overflow-y: auto;
  max-height: calc(100% - 8rem);
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.qm-list-container::-webkit-scrollbar {
  display: none;
}

.qm-list-content {
  width: 100%;
}

.qm-list-items {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.qm-list-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  transition: all 0.2s;
  cursor: pointer;
}

.qm-list-item:hover {
  background-color: var(--color-base-200);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.qm-item-icon {
  width: 2rem;
  height: 2rem;
  border-radius: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  flex-shrink: 0;
}

.qm-icon-income {
  background-color: #dcfce7;
  color: #16a34a;
}

.qm-icon-expense {
  background-color: #fee2e2;
  color: #ef4444;
}

.qm-icon-transfer {
  background-color: #dbeafe;
  color: #3b82f6;
}

.qm-icon-budget {
  background-color: #ffedd5;
  color: #f97316;
}

.qm-icon-reminder {
  background-color: #fef9c3;
  color: #ca8a04;
}

.qm-item-content {
  flex: 1;
  min-width: 0;
}

.qm-item-name {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-base-content);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.qm-item-desc {
  font-size: 0.75rem;
  color: var(--color-base-content);
  opacity: 0.6;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.qm-item-value-wrapper {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.25rem;
  flex-shrink: 0;
}

.qm-item-value {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.qm-item-date {
  font-size: 0.625rem;
  color: var(--color-base-content);
  opacity: 0.5;
  text-align: right;
}

.qm-value-income {
  color: #16a34a;
}

.qm-value-expense {
  color: #ef4444;
}

.qm-empty-state {
  text-align: center;
  padding: 2rem 1rem;
  color: var(--color-base-content);
  opacity: 0.5;
  font-size: 0.875rem;
}

.qm-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0.875rem;
  border: none;
  border-radius: 0.75rem;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  flex-shrink: 0;
}

.qm-btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 3px 6px rgba(0, 0, 0, 0.12);
}

.qm-btn:active {
  transform: translateY(0);
}

.qm-btn-purple {
  background-color: #f3e8ff;
  color: #8b5cf6;
}

.qm-btn-purple:hover {
  background-color: #e9d5ff;
}

.qm-btn-green {
  background-color: #dcfce7;
  color: #16a34a;
}

.qm-btn-green:hover {
  background-color: #bbf7d0;
}

.qm-btn-red {
  background-color: #fee2e2;
  color: #ef4444;
}

.qm-btn-red:hover {
  background-color: #fecaca;
}

.qm-btn-blue {
  background-color: #dbeafe;
  color: #3b82f6;
}

.qm-btn-blue:hover {
  background-color: #bfdbfe;
}

.qm-btn-orange {
  background-color: #ffedd5;
  color: #f97316;
}

.qm-btn-orange:hover {
  background-color: #fed7aa;
}

.qm-btn-yellow {
  background-color: #fef9c3;
  color: #ca8a04;
}

.qm-btn-yellow:hover {
  background-color: #fef08a;
}

.qm-btn-gray {
  background-color: #f3f4f6;
  color: #6b7280;
}

.qm-btn-gray:hover {
  background-color: #e5e7eb;
}

/* 响应式调整 */
@media (max-width: 768px) {
  .qm-quick-money-container {
    padding: 0.5rem;
    padding-top: 0.5rem;
  }

  .qm-btn {
    padding: 0.75rem;
  }

  .qm-help-toggle {
    top: 0.25rem;
    right: 0.25rem;
    padding: 0.375rem;
  }

  .qm-keyboard-help {
    top: 0.25rem;
    left: 0.25rem;
    max-width: 160px;
    font-size: 0.75rem;
  }
  .qm-quick-actions {
    gap: 0.375rem;
  }

  .qm-tab-btn {
    padding: 0.375rem 0.5rem;
    font-size: 0.75rem;
  }

  .qm-list-item {
    padding: 0.5rem;
    gap: 0.5rem;
  }

  .qm-item-icon {
    width: 1.5rem;
    height: 1.5rem;
  }

  .qm-item-name {
    font-size: 0.8125rem;
  }

  .qm-item-desc {
    font-size: 0.6875rem;
  }

  .qm-item-value {
    font-size: 0.8125rem;
  }

  .qm-item-date {
    font-size: 0.5625rem;
  }

  .qm-item-value-wrapper {
    min-width: 0;
  }
}

@media (min-width: 1024px) {
  .qm-btn {
    padding: 1rem;
  }
}
</style>
