<script setup lang="ts">
import ConfirmModal from '@/components/common/ConfirmModal.vue';
import { useConfirm } from '@/composables/useConfirm';
import AccountModal from '@/features/money/components/AccountModal.vue';
import BudgetModal from '@/features/money/components/BudgetModal.vue';
import ReminderModal from '@/features/money/components/ReminderModal.vue';
import TransactionModal from '@/features/money/components/TransactionModal.vue';
import { TransactionTypeSchema } from '@/schema/common';
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

onMounted(async () => {
  await loadAccounts();
  await moneyStore.getAllCategories();
  await moneyStore.getAllSubCategories();
  window.addEventListener('keydown', handleKeyPress);
});

onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyPress);
});
</script>

<template>
  <div class="quick-money-container">
    <!-- 快捷键帮助提示 - 左上角 -->
    <div class="keyboard-help" :class="{ show: showKeyboardHelp }">
      <div class="help-header">
        <h4>快捷键</h4>
        <button class="close-btn" @click="showKeyboardHelp = false">
          <LucideX :size="16" />
        </button>
      </div>
      <div class="shortcuts-list">
        <div v-for="shortcut in keyboardShortcuts" :key="shortcut.key" class="shortcut-item">
          <kbd class="shortcut-key">{{ shortcut.key }}</kbd>
          <span class="shortcut-label">{{ shortcut.label }}</span>
        </div>
      </div>
    </div>

    <!-- 快捷键提示按钮 - 右上角 -->
    <button class="help-toggle" title="快捷键帮助 (?)" @click="showKeyboardHelp = !showKeyboardHelp">
      <LucideKeyboard :size="20" />
    </button>

    <div class="quick-actions">
      <button class="btn btn-purple" title="添加账户" @click="showAccountModal">
        <LucideCreditCard :size="12" />
      </button>
      <button class="btn btn-green" title="记录收入" @click="showTransactionModal(TransactionTypeSchema.enum.Income)">
        <LucidePlusCircle :size="12" />
      </button>
      <button class="btn btn-red" title="记录支出" @click="showTransactionModal(TransactionTypeSchema.enum.Expense)">
        <LucideMinusCircle :size="12" />
      </button>
      <button class="btn btn-blue" title="记录转账" @click="showTransactionModal(TransactionTypeSchema.enum.Transfer)">
        <LucideArrowRightLeft :size="12" />
      </button>
      <button class="btn btn-orange" title="设置预算" @click="showBudgetModal">
        <LucideTarget :size="12" />
      </button>
      <button class="btn btn-yellow" title="设置提醒" @click="showReminderModal">
        <LucideBell :size="12" />
      </button>
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
.quick-money-container {
  width: 100%;
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  height: 100%;
  padding: 1rem;
  padding-top: 1rem;
  overflow: visible;
}

/* 快捷键帮助提示框 - 左上角 */
.keyboard-help {
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

.keyboard-help.show {
  opacity: 1;
  transform: translateY(0);
  pointer-events: auto;
}

.help-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--color-base-300);
}

.help-header h4 {
  margin: 0;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.close-btn {
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

.close-btn:hover {
  opacity: 1;
}

.shortcuts-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.shortcut-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
}

.shortcut-key {
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

.shortcut-label {
  color: var(--color-base-content);
}

/* 快捷键帮助按钮 - 右上角 */
.help-toggle {
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

.help-toggle:hover {
  opacity: 1;
  background-color: var(--color-base-200);
  transform: scale(1.05);
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
}

.quick-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  width: 100%;
  align-items: center;
  justify-content: center;
}

.btn {
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

.btn:hover {
  transform: translateY(-1px);
  box-shadow: 0 3px 6px rgba(0, 0, 0, 0.12);
}

.btn:active {
  transform: translateY(0);
}

.btn-purple {
  background-color: #f3e8ff;
  color: #8b5cf6;
}

.btn-purple:hover {
  background-color: #e9d5ff;
}

.btn-green {
  background-color: #dcfce7;
  color: #16a34a;
}

.btn-green:hover {
  background-color: #bbf7d0;
}

.btn-red {
  background-color: #fee2e2;
  color: #ef4444;
}

.btn-red:hover {
  background-color: #fecaca;
}

.btn-blue {
  background-color: #dbeafe;
  color: #3b82f6;
}

.btn-blue:hover {
  background-color: #bfdbfe;
}

.btn-orange {
  background-color: #ffedd5;
  color: #f97316;
}

.btn-orange:hover {
  background-color: #fed7aa;
}

.btn-yellow {
  background-color: #fef9c3;
  color: #ca8a04;
}

.btn-yellow:hover {
  background-color: #fef08a;
}

/* 响应式调整 */
@media (max-width: 768px) {
  .quick-money-container {
    padding-top: 0.75rem;
  }

  .btn {
    padding: 0.75rem;
  }

  .help-toggle {
    top: 0.375rem;
    right: 0.375rem;
    padding: 0.375rem;
  }

  .keyboard-help {
    top: 0.375rem;
    left: 0.375rem;
    max-width: 160px;
    font-size: 0.75rem;
  }
  .quick-actions {
    gap: 0.375rem;
  }
}

@media (min-width: 1024px) {
  .btn {
    padding: 1rem;
  }
}
</style>
