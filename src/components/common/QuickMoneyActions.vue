<script setup lang="ts">
// 閲嶆瀯鍚庣殑QuickMoneyActions - 浣跨敤缁勪欢鍖栨灦鏋?
import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
import QuickMoneyAccountList from '@/components/common/QuickMoneyAccountList.vue';
import QuickMoneyActionButtons from '@/components/common/QuickMoneyActionButtons.vue';
import QuickMoneyBudgetList from '@/components/common/QuickMoneyBudgetList.vue';
import QuickMoneyHeader from '@/components/common/QuickMoneyHeader.vue';
import QuickMoneyReminderList from '@/components/common/QuickMoneyReminderList.vue';
import QuickMoneyTabs from '@/components/common/QuickMoneyTabs.vue';
import QuickMoneyTransactionList from '@/components/common/QuickMoneyTransactionList.vue';
import AccountModal from '@/features/money/components/AccountModal.vue';
import BudgetModal from '@/features/money/components/BudgetModal.vue';
import ReminderModal from '@/features/money/components/ReminderModal.vue';
import TransactionModal from '@/features/money/components/TransactionModal.vue';
import { TransactionTypeSchema } from '@/schema/common';
import { useAccountStore, useCategoryStore } from '@/stores/money';
import type {
  BilReminderCreate,
  BilReminderUpdate,
  BudgetCreate,
  BudgetUpdate,
  CreateAccountRequest,
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

const accountStore = useAccountStore();
const categoryStore = useCategoryStore();
const mediaQueries = useMediaQueriesStore();
const { confirmState, handleConfirm, handleCancel, handleClose } = useConfirm();

// 浣跨敤鍚勪釜鍔熻兘妯″潡鐨?hooks
const {
  showTransaction,
  selectedTransaction,
  transactionType,
  showTransactionModal,
  closeTransactionModal,
  handleSaveTransaction: saveTransaction,
  handleUpdateTransaction: updateTransaction,
  handleSaveTransfer: saveTransfer,
  handleUpdateTransfer: updateTransfer,
} = useTransactionActions();

const {
  showAccount,
  selectedAccount,
  accounts,
  showAccountModal,
  closeAccountModal,
  handleSaveAccount: saveAccount,
  handleUpdateAccount: updateAccount,
  loadAccounts,
} = useAccountActions();

const {
  showBudget,
  selectedBudget,
  budgets,
  showBudgetModal,
  closeBudgetModal,
  handleSaveBudget: saveBudget,
  handleUpdateBudget: updateBudget,
  loadBudgets,
} = useBudgetActions();

const {
  showReminder,
  selectedReminder,
  reminders,
  showReminderModal,
  closeReminderModal,
  handleSaveReminder: saveReminder,
  handleUpdateReminder: updateReminder,
  loadReminders,
} = useReminderActions();

const {
  showKeyboardHelp,
  keyboardShortcuts,
  createKeyboardHandler,
  addKeyboardListener,
} = useKeyboardShortcuts();

const {
  activeTab,
  transactions,
  loadTransactions,
  switchTab,
} = useTabManager();

// 鍏抽棴鎵€鏈夋ā鎬佹
function closeAllModals() {
  closeTransactionModal();
  closeAccountModal();
  closeBudgetModal();
  closeReminderModal();
}

// 鍒囨崲閲戦鍙鎬?
function toggleAmountVisibility() {
  accountStore.toggleGlobalAmountHidden();
}

// 鏁版嵁鍒锋柊鍑芥暟
async function refreshTransactionData() {
  await Promise.all([loadTransactions(), loadAccounts(), loadBudgets()]);
}

async function refreshAccountData() {
  await loadAccounts();
}

async function refreshBudgetData() {
  await loadBudgets();
}

async function refreshReminderData() {
  await loadReminders();
}

// 浣跨敤composables涓殑handle鏂规硶锛岄€氳繃鍥炶皟瀹炵幇鏁版嵁鍒锋柊
async function handleSaveTransaction(transaction: TransactionCreate) {
  return await saveTransaction(transaction, refreshTransactionData);
}

async function handleUpdateTransaction(serialNum: string, transaction: TransactionUpdate) {
  return await updateTransaction(serialNum, transaction, refreshTransactionData);
}

async function handleSaveTransfer(transfer: TransferCreate) {
  return await saveTransfer(transfer, refreshTransactionData);
}

async function handleUpdateTransfer(serialNum: string, transfer: TransferCreate) {
  return await updateTransfer(serialNum, transfer, refreshTransactionData);
}

async function handleSaveAccount(account: CreateAccountRequest) {
  return await saveAccount(account, refreshAccountData);
}

async function handleUpdateAccount(serialNum: string, account: UpdateAccountRequest) {
  return await updateAccount(serialNum, account, refreshAccountData);
}

async function handleSaveBudget(budget: BudgetCreate) {
  return await saveBudget(budget, refreshBudgetData);
}

async function handleUpdateBudget(serialNum: string, budget: BudgetUpdate) {
  return await updateBudget(serialNum, budget, refreshBudgetData);
}

async function handleSaveReminder(reminder: BilReminderCreate) {
  return await saveReminder(reminder, refreshReminderData);
}

async function handleUpdateReminder(serialNum: string, reminder: BilReminderUpdate) {
  return await updateReminder(serialNum, reminder, refreshReminderData);
}

// 鍒涘缓閿洏浜嬩欢澶勭悊鍣?
const handleKeyPress = createKeyboardHandler(
  {
    showTransaction,
    showAccount,
    showBudget,
    showReminder,
  },
  {
    showAccountModal,
    showTransactionModal,
    showBudgetModal,
    showReminderModal,
    closeAllModals,
  },
);

// 娣诲姞閿洏浜嬩欢鐩戝惉鍣?
addKeyboardListener(handleKeyPress);

// 鏍囩鍒囨崲澶勭悊
function handleSwitchTab(tab: 'accounts' | 'transactions' | 'budgets' | 'reminders') {
  switchTab(tab, {
    loadAccounts,
    loadTransactions,
    loadBudgets,
    loadReminders,
  });
}

onMounted(async () => {
  await loadAccounts();
  await categoryStore.fetchCategories();
  await categoryStore.fetchSubCategories();
  // 鍒濆鍔犺浇鎵€鏈夋暟鎹?
  await loadTransactions();
  await loadBudgets();
  await loadReminders();
});
</script>

<template>
  <div class="w-full relative flex flex-col items-center justify-start h-full p-1 pt-1 overflow-hidden">
    <!-- 蹇嵎閿府鍔╃郴缁? -->
    <QuickMoneyHeader
      :show="showKeyboardHelp"
      :shortcuts="keyboardShortcuts"
      :is-mobile="mediaQueries.isMobile"
      @toggle="showKeyboardHelp = !showKeyboardHelp"
      @close="showKeyboardHelp = false"
    />

    <!-- 蹇嵎鎿嶄綔鎸夐挳 -->
    <QuickMoneyActionButtons
      :show-amount-toggle="props.showAmountToggle"
      :amount-hidden="accountStore.globalAmountHidden"
      @add-account="showAccountModal"
      @add-income="showTransactionModal(TransactionTypeSchema.enum.Income)"
      @add-expense="showTransactionModal(TransactionTypeSchema.enum.Expense)"
      @add-transfer="showTransactionModal(TransactionTypeSchema.enum.Transfer)"
      @add-budget="showBudgetModal"
      @add-reminder="showReminderModal"
      @toggle-amount="toggleAmountVisibility"
    />

    <!-- Tab鍒囨崲 -->
    <QuickMoneyTabs
      :active-tab="activeTab"
      @switch="handleSwitchTab"
    />

    <!-- 鍒楄〃瀹瑰櫒 -->
    <div class="w-full flex-1 overflow-y-auto max-h-[calc(100%-8rem)] scrollbar-none">
      <!-- 璐︽埛鍒楄〃 -->
      <QuickMoneyAccountList
        v-if="activeTab === 'accounts'"
        :accounts="accounts"
        :amount-hidden="accountStore.globalAmountHidden"
      />

      <!-- 浜ゆ槗鍒楄〃 -->
      <QuickMoneyTransactionList
        v-if="activeTab === 'transactions'"
        :transactions="transactions"
      />

      <!-- 棰勭畻鍒楄〃 -->
      <QuickMoneyBudgetList
        v-if="activeTab === 'budgets'"
        :budgets="budgets"
      />

      <!-- 鎻愰啋鍒楄〃 -->
      <QuickMoneyReminderList
        v-if="activeTab === 'reminders'"
        :reminders="reminders"
      />
    </div>

    <!-- Modals - 浣跨敤 Teleport 浼犻€佸埌 body锛岀‘淇濊鐩栨暣涓〉闈? -->
    <Teleport to="body">
      <TransactionModal
        v-if="showTransaction"
        :type="transactionType"
        :transaction="selectedTransaction"
        :accounts="accounts"
        @close="closeTransactionModal"
        @save="handleSaveTransaction"
        @update="handleUpdateTransaction"
        @save-transfer="handleSaveTransfer"
        @update-transfer="handleUpdateTransfer"
      />
      <AccountModal
        v-if="showAccount"
        :account="selectedAccount"
        @close="closeAccountModal"
        @save="handleSaveAccount"
        @update="handleUpdateAccount"
      />
      <BudgetModal
        v-if="showBudget"
        :budget="selectedBudget"
        @close="closeBudgetModal"
        @save="handleSaveBudget"
        @update="handleUpdateBudget"
      />
      <ReminderModal
        v-if="showReminder"
        :reminder="selectedReminder"
        @close="closeReminderModal"
        @save="handleSaveReminder"
        @update="handleUpdateReminder"
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
        @confirm="handleConfirm"
        @cancel="handleCancel"
        @close="handleClose"
      />
    </Teleport>
  </div>
</template>
