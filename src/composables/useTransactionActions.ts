import { TransactionTypeSchema } from '@/schema/common';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { TransactionType } from '@/schema/common';
import type {
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
} from '@/schema/money';

export function useTransactionActions() {
  const moneyStore = useMoneyStore();

  const showTransaction = ref(false);
  const selectedTransaction = ref<Transaction | null>(null);
  const transactionType = ref<TransactionType>(TransactionTypeSchema.enum.Expense);

  // 显示交易模态框
  function showTransactionModal(type: TransactionType) {
    transactionType.value = type;
    selectedTransaction.value = null;
    showTransaction.value = true;
  }

  // 关闭交易模态框
  function closeTransactionModal() {
    showTransaction.value = false;
    selectedTransaction.value = null;
  }

  // 编辑交易
  function editTransaction(transaction: Transaction) {
    selectedTransaction.value = transaction;
    transactionType.value = transaction.transactionType;
    showTransaction.value = true;
  }

  // 保存交易
  async function saveTransaction(transaction: TransactionCreate) {
    try {
      // 如果是分期付款，需要先创建交易，然后创建分期计划
      if (transaction.isInstallment) {
        // 1. 创建交易（不更新账户余额）
        const createdTransaction = await moneyStore.createTransaction(transaction);

        // 2. 创建分期计划
        await moneyStore.createInstallmentPlan({
          transaction_serial_num: createdTransaction.serialNum,
          total_amount: transaction.amount,
          total_periods: transaction.totalPeriods || 0,
          installment_amount: transaction.amount / (transaction.totalPeriods || 1),
          first_due_date: transaction.date,
        });

        toast.success('分期付款创建成功');
      } else {
        // 普通交易
        await moneyStore.createTransaction(transaction);
        toast.success('添加成功');
      }

      closeTransactionModal();
      return true;
    } catch (err) {
      Lg.e('saveTransaction', err);
      toast.error('保存失败');
      return false;
    }
  }

  // 更新交易
  async function updateTransaction(serialNum: string, transaction: TransactionUpdate) {
    try {
      if (selectedTransaction.value) {
        await moneyStore.updateTransaction(serialNum, transaction);
        toast.success('更新成功');
        closeTransactionModal();
        return true;
      }
      return false;
    } catch (err) {
      Lg.e('updateTransaction', err);
      toast.error('保存失败');
      return false;
    }
  }

  // 删除交易
  async function deleteTransaction(
    transaction: Transaction,
    confirmDelete?: (message: string) => Promise<boolean>,
  ) {
    if (confirmDelete && !(await confirmDelete('此交易记录'))) {
      return false;
    }

    try {
      if (transaction.category === 'Transfer' && transaction.relatedTransactionSerialNum) {
        await moneyStore.deleteTransfer(transaction.relatedTransactionSerialNum);
        toast.success('转账记录删除成功');
      } else {
        await moneyStore.deleteTransaction(transaction.serialNum);
        toast.success('删除成功');
      }
      return true;
    } catch (err) {
      Lg.e('deleteTransaction', err);
      toast.error('删除失败');
      return false;
    }
  }

  // 保存转账
  async function saveTransfer(transfer: TransferCreate) {
    try {
      await moneyStore.createTransfer(transfer);
      toast.success('转账成功');
      closeTransactionModal();
      return true;
    } catch (err) {
      Lg.e('saveTransfer', err);
      toast.error('转账失败');
      return false;
    }
  }

  // 更新转账
  async function updateTransfer(serialNum: string, transfer: TransferCreate) {
    try {
      await moneyStore.updateTransfer(serialNum, transfer);
      toast.success('转账更新成功');
      closeTransactionModal();
      return true;
    } catch (err) {
      Lg.e('updateTransfer', err);
      toast.error('转账失败');
      return false;
    }
  }

  // 查看交易详情
  function viewTransactionDetails(transaction: Transaction) {
    Lg.d('viewTransactionDetails', '查看交易详情:', transaction);
  }

  // 包装保存方法，支持自定义回调
  async function handleSaveTransaction(
    transaction: TransactionCreate,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await saveTransaction(transaction);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装更新方法，支持自定义回调
  async function handleUpdateTransaction(
    serialNum: string,
    transaction: TransactionUpdate,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await updateTransaction(serialNum, transaction);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装删除方法，支持自定义回调
  async function handleDeleteTransaction(
    transaction: Transaction,
    confirmDelete?: (message: string) => Promise<boolean>,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await deleteTransaction(transaction, confirmDelete);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装保存转账方法，支持自定义回调
  async function handleSaveTransfer(
    transfer: TransferCreate,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await saveTransfer(transfer);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装更新转账方法，支持自定义回调
  async function handleUpdateTransfer(
    serialNum: string,
    transfer: TransferCreate,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await updateTransfer(serialNum, transfer);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  return {
    // 状态
    showTransaction,
    selectedTransaction,
    transactionType,

    // 基础方法
    showTransactionModal,
    closeTransactionModal,
    editTransaction,
    saveTransaction,
    updateTransaction,
    deleteTransaction,
    saveTransfer,
    updateTransfer,
    viewTransactionDetails,

    // 包装方法（支持回调）
    handleSaveTransaction,
    handleUpdateTransaction,
    handleDeleteTransaction,
    handleSaveTransfer,
    handleUpdateTransfer,
  };
}
