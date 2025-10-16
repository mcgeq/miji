import { ref } from 'vue';
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

  // 保存交易
  async function saveTransaction(transaction: TransactionCreate) {
    try {
      await moneyStore.createTransaction(transaction);
      toast.success('添加成功');
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

  return {
    // 状态
    showTransaction,
    selectedTransaction,
    transactionType,

    // 方法
    showTransactionModal,
    closeTransactionModal,
    saveTransaction,
    updateTransaction,
    saveTransfer,
    updateTransfer,
  };
}
