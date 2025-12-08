import type { TransactionType } from '@/schema/common';
import { TransactionTypeSchema } from '@/schema/common';
import type {
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
} from '@/schema/money';
import { useTransactionStore } from '@/stores/money';
import { toast } from '@/utils/toast';

/**
 * 交易操作 Composable - 重构版本
 *
 * 注意：Transaction 比较特殊，不完全适用 useCrudActions
 * 因为它有多种类型（Expense, Income, Transfer）和特殊的转账逻辑
 */
export function useTransactionActions() {
  const transactionStore = useTransactionStore();
  const { t } = useI18n();

  // 状态
  const showTransaction = ref(false);
  const selectedTransaction = ref<Transaction | null>(null);
  const transactionType = ref<TransactionType>(TransactionTypeSchema.enum.Expense);
  const isViewMode = ref(false);
  const loading = ref(false);

  /**
   * 显示交易模态框
   */
  function showTransactionModal(type: TransactionType) {
    transactionType.value = type;
    selectedTransaction.value = null;
    isViewMode.value = false;
    showTransaction.value = true;
  }

  /**
   * 关闭交易模态框
   */
  function closeTransactionModal() {
    showTransaction.value = false;
    selectedTransaction.value = null;
    isViewMode.value = false;
  }

  /**
   * 编辑交易
   */
  function editTransaction(transaction: Transaction) {
    selectedTransaction.value = transaction;
    transactionType.value = transaction.transactionType;
    isViewMode.value = false;
    showTransaction.value = true;
  }

  /**
   * 查看交易详情
   */
  function viewTransactionDetails(transaction: Transaction) {
    selectedTransaction.value = transaction;
    transactionType.value = transaction.transactionType as TransactionType;
    isViewMode.value = true;
    showTransaction.value = true;
  }

  /**
   * 保存交易
   */
  async function handleSaveTransaction(
    transaction: TransactionCreate,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    loading.value = true;
    try {
      await transactionStore.createTransaction(transaction);
      toast.success(t('financial.messages.transactionCreated'));
      closeTransactionModal();

      if (onSuccess) {
        await onSuccess();
      }

      return true;
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : t('financial.messages.transactionCreateFailed');
      toast.error(message);
      return false;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 更新交易
   */
  async function handleUpdateTransaction(
    serialNum: string,
    transaction: TransactionUpdate,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    if (!selectedTransaction.value) {
      return false;
    }

    loading.value = true;
    try {
      await transactionStore.updateTransaction(serialNum, transaction);
      toast.success(t('financial.messages.transactionUpdated'));
      closeTransactionModal();

      if (onSuccess) {
        await onSuccess();
      }

      return true;
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : t('financial.messages.transactionUpdateFailed');
      toast.error(message);
      return false;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 删除交易
   */
  async function handleDeleteTransaction(
    transaction: Transaction,
    confirmDelete?: (message: string) => Promise<boolean>,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    if (confirmDelete && !(await confirmDelete(t('financial.messages.confirmDeleteTransaction')))) {
      return false;
    }

    loading.value = true;
    try {
      // 特殊处理：转账需要删除关联的交易
      if (transaction.category === 'Transfer' && transaction.relatedTransactionSerialNum) {
        await transactionStore.deleteTransfer(transaction.relatedTransactionSerialNum);
        toast.success(t('financial.messages.transferDeleted'));
      } else {
        await transactionStore.deleteTransaction(transaction.serialNum);
        toast.success(t('financial.messages.transactionDeleted'));
      }

      if (onSuccess) {
        await onSuccess();
      }

      return true;
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : t('financial.messages.transactionDeleteFailed');
      toast.error(message);
      return false;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 保存转账
   */
  async function handleSaveTransfer(
    transfer: TransferCreate,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    loading.value = true;
    try {
      await transactionStore.createTransfer(transfer);
      toast.success(t('financial.messages.transferCreated'));
      closeTransactionModal();

      if (onSuccess) {
        await onSuccess();
      }

      return true;
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : t('financial.messages.transferCreateFailed');
      toast.error(message);
      return false;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 更新转账
   */
  async function handleUpdateTransfer(
    serialNum: string,
    transfer: TransferCreate,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    loading.value = true;
    try {
      await transactionStore.updateTransfer(serialNum, transfer);
      toast.success(t('financial.messages.transferUpdated'));
      closeTransactionModal();

      if (onSuccess) {
        await onSuccess();
      }

      return true;
    } catch (error: unknown) {
      const message =
        error instanceof Error ? error.message : t('financial.messages.transferUpdateFailed');
      toast.error(message);
      return false;
    } finally {
      loading.value = false;
    }
  }

  return {
    // 状态
    showTransaction: readonly(showTransaction),
    selectedTransaction: computed(() => selectedTransaction.value as Transaction | null),
    transactionType: readonly(transactionType),
    isViewMode: readonly(isViewMode),
    loading: readonly(loading),

    // 方法
    showTransactionModal,
    closeTransactionModal,
    editTransaction,
    viewTransactionDetails,
    handleSaveTransaction,
    handleUpdateTransaction,
    handleDeleteTransaction,
    handleSaveTransfer,
    handleUpdateTransfer,
  };
}
