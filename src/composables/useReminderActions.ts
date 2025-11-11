import { MoneyDb } from '@/services/money/money';
import { useReminderStore } from '@/stores/money';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { BilReminder, BilReminderCreate, BilReminderUpdate } from '@/schema/money';

export function useReminderActions() {
  const reminderStore = useReminderStore();

  const showReminder = ref(false);
  const selectedReminder = ref<BilReminder | null>(null);
  const reminders = ref<BilReminder[]>([]);

  // 显示提醒模态框
  function showReminderModal() {
    selectedReminder.value = null;
    showReminder.value = true;
  }

  // 关闭提醒模态框
  function closeReminderModal() {
    showReminder.value = false;
    selectedReminder.value = null;
  }

  // 编辑提醒
  function editReminder(reminder: BilReminder) {
    selectedReminder.value = reminder;
    showReminder.value = true;
  }

  // 保存提醒
  async function saveReminder(reminder: BilReminderCreate) {
    try {
      await reminderStore.createReminder(reminder);
      toast.success('添加成功');
      closeReminderModal();
      return true;
    } catch (err) {
      Lg.e('saveReminder', err);
      toast.error('保存失败');
      return false;
    }
  }

  // 更新提醒
  async function updateReminder(serialNum: string, reminder: BilReminderUpdate) {
    try {
      if (selectedReminder.value) {
        await reminderStore.updateReminder(serialNum, reminder);
        toast.success('更新成功');
        closeReminderModal();
        return true;
      }
      return false;
    } catch (err) {
      Lg.e('updateReminder', err);
      toast.error('保存失败');
      return false;
    }
  }

  // 删除提醒
  async function deleteReminder(
    serialNum: string,
    confirmDelete?: (message: string) => Promise<boolean>,
  ) {
    if (confirmDelete && !(await confirmDelete('此提醒'))) {
      return false;
    }

    try {
      await reminderStore.deleteReminder(serialNum);
      toast.success('删除成功');
      return true;
    } catch (err) {
      Lg.e('deleteReminder', err);
      toast.error('删除失败');
      return false;
    }
  }

  // 标记提醒已付/未付
  async function markReminderPaid(serialNum: string, isPaid: boolean) {
    try {
      // TODO: 添加到reminderStore中
      await MoneyDb.updateBilReminderActive(serialNum, isPaid);
      toast.success('标记成功');
      return true;
    } catch (err) {
      Lg.e('markReminderPaid', err);
      toast.error('标记失败');
      return false;
    }
  }

  // 加载提醒列表
  async function loadReminders() {
    try {
      await reminderStore.fetchReminders();
      reminders.value = reminderStore.reminders;
      return true;
    } catch (err) {
      Lg.e('loadReminders', err);
      return false;
    }
  }

  // 包装保存方法，支持自定义回调
  async function handleSaveReminder(
    reminder: BilReminderCreate,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await saveReminder(reminder);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装更新方法，支持自定义回调
  async function handleUpdateReminder(
    serialNum: string,
    reminder: BilReminderUpdate,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await updateReminder(serialNum, reminder);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装删除方法，支持自定义回调
  async function handleDeleteReminder(
    serialNum: string,
    confirmDelete?: (message: string) => Promise<boolean>,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await deleteReminder(serialNum, confirmDelete);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装标记已付方法，支持自定义回调
  async function handleMarkReminderPaid(
    serialNum: string,
    isPaid: boolean,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await markReminderPaid(serialNum, isPaid);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  return {
    // 状态
    showReminder,
    selectedReminder,
    reminders,

    // 基础方法
    showReminderModal,
    closeReminderModal,
    editReminder,
    saveReminder,
    updateReminder,
    deleteReminder,
    markReminderPaid,
    loadReminders,

    // 包装方法（支持回调）
    handleSaveReminder,
    handleUpdateReminder,
    handleDeleteReminder,
    handleMarkReminderPaid,
  };
}
