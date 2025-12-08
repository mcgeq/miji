<script setup lang="ts">
  // 重构后的QuickMoneyActions - 使用组件化架构
  import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
  import QuickMoneyAccountList from '@/components/common/QuickMoneyAccountList.vue';
  import QuickMoneyActionButtons from '@/components/common/QuickMoneyActionButtons.vue';
  import QuickMoneyBudgetList from '@/components/common/QuickMoneyBudgetList.vue';
  import QuickMoneyHeader from '@/components/common/QuickMoneyHeader.vue';
  import QuickMoneyReminderList from '@/components/common/QuickMoneyReminderList.vue';
  import QuickMoneyTabs from '@/components/common/QuickMoneyTabs.vue';
  import QuickMoneyTransactionList from '@/components/common/QuickMoneyTransactionList.vue';
  import { TransactionTypeSchema } from '@/schema/common';
  import { useAccountStore, useCategoryStore } from '@/stores/money';

  // 懒加载模态框组件 (Task 27: 按需加载，减少首屏加载时间)
  const AccountModal = defineAsyncComponent(
    () => import('@/features/money/components/AccountModal.vue'),
  );
  const BudgetModal = defineAsyncComponent(
    () => import('@/features/money/components/BudgetModal.vue'),
  );
  const ReminderModal = defineAsyncComponent(
    () => import('@/features/money/components/ReminderModal.vue'),
  );
  const TransactionModal = defineAsyncComponent(
    () => import('@/features/money/components/TransactionModal.vue'),
  );

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

  // 使用各个功能模块的 hooks
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

  const { showKeyboardHelp, keyboardShortcuts, createKeyboardHandler, addKeyboardListener } =
    useKeyboardShortcuts();

  const { activeTab, transactions, loadTransactions, switchTab } = useTabManager();

  // 关闭所有模态框
  function closeAllModals() {
    closeTransactionModal();
    closeAccountModal();
    closeBudgetModal();
    closeReminderModal();
  }

  // 切换金额可见性
  function toggleAmountVisibility() {
    accountStore.toggleGlobalAmountHidden();
  }

  // 刷新交易数据
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

  // 钱包操作相关处理函数
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

  // 创建键盘事件处理器
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

  // 添加键盘事件监听器
  addKeyboardListener(handleKeyPress);

  // 标签切换处理
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
    // 初始加载所有数据
    await loadTransactions();
    await loadBudgets();
    await loadReminders();
  });
</script>

<template>
  <div
    class="w-full relative flex flex-col items-center justify-start h-full p-1 pt-1 overflow-hidden"
  >
    <!-- 快捷键帮助系统 -->
    <QuickMoneyHeader
      :show="showKeyboardHelp"
      :shortcuts="keyboardShortcuts"
      :is-mobile="mediaQueries.isMobile"
      @toggle="showKeyboardHelp = !showKeyboardHelp"
      @close="showKeyboardHelp = false"
    />

    <!-- 快捷操作按钮 -->
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

    <!-- Tab切换 -->
    <QuickMoneyTabs :active-tab="activeTab" @switch="handleSwitchTab" />

    <!-- 列表容器 -->
    <div class="w-full flex-1 overflow-y-auto max-h-[calc(100%-8rem)] scrollbar-none">
      <!-- 账户列表 -->
      <QuickMoneyAccountList
        v-if="activeTab === 'accounts'"
        :accounts="accounts"
        :amount-hidden="accountStore.globalAmountHidden"
      />

      <!-- 交易列表 -->
      <QuickMoneyTransactionList v-if="activeTab === 'transactions'" :transactions="transactions" />

      <!-- 预算列表 -->
      <QuickMoneyBudgetList v-if="activeTab === 'budgets'" :budgets="budgets" />

      <!-- 提醒列表 -->
      <QuickMoneyReminderList v-if="activeTab === 'reminders'" :reminders="reminders" />
    </div>

    <!-- Modals - 使用 Teleport 传送到 body，确保覆盖整个页面 -->
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
