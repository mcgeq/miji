import { useCrudActions } from '@/composables/useCrudActions';
import { MoneyDb } from '@/services/money/money';
import { useReminderStore } from '@/stores/money';
import { toast } from '@/utils/toast';
import type { BilReminder, BilReminderCreate, BilReminderUpdate } from '@/schema/money';

/**
 * 提醒操作 Composable - 重构版本
 * 使用 useCrudActions 简化代码
 */
export function useReminderActions() {
  const reminderStore = useReminderStore();
  const { t } = useI18n();

  // 创建 Store 适配器
  const storeAdapter = {
    create: (data: BilReminderCreate) => reminderStore.createReminder(data),
    update: (id: string, data: BilReminderUpdate) => reminderStore.updateReminder(id, data),
    delete: (id: string) => reminderStore.deleteReminder(id),
    fetchAll: () => reminderStore.fetchReminders(),
  };

  // 使用通用 CRUD Actions
  const crudActions = useCrudActions<BilReminder, BilReminderCreate, BilReminderUpdate>(
    storeAdapter,
    {
      successMessages: {
        create: t('financial.messages.reminderCreated'),
        update: t('financial.messages.reminderUpdated'),
        delete: t('financial.messages.reminderDeleted'),
      },
      errorMessages: {
        create: t('financial.messages.reminderCreateFailed'),
        update: t('financial.messages.reminderUpdateFailed'),
        delete: t('financial.messages.reminderDeleteFailed'),
      },
      autoRefresh: true,
      autoClose: true,
    },
  );

  // 提醒列表状态
  const reminders = computed(() => reminderStore.reminders);

  /**
   * 标记提醒已付/未付
   */
  async function markReminderPaid(
    serialNum: string,
    isPaid: boolean,
  ): Promise<boolean> {
    try {
      // TODO: 添加到 reminderStore 中
      await MoneyDb.updateBilReminderActive(serialNum, isPaid);
      toast.success(
        isPaid
          ? t('financial.messages.reminderMarkedPaid')
          : t('financial.messages.reminderMarkedUnpaid'),
      );

      // 刷新列表
      if (storeAdapter.fetchAll) {
        await storeAdapter.fetchAll();
      }

      return true;
    } catch (error: any) {
      toast.error(error.message || t('financial.messages.reminderMarkFailed'));
      return false;
    }
  }

  /**
   * 包装标记已付方法，支持自定义回调
   */
  async function handleMarkReminderPaid(
    serialNum: string,
    isPaid: boolean,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    const success = await markReminderPaid(serialNum, isPaid);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  return {
    // 从 useCrudActions 继承的状态和方法
    showReminder: crudActions.show,
    selectedReminder: crudActions.selected,
    isViewMode: crudActions.isViewMode,
    loading: crudActions.loading,

    // 从 useCrudActions 继承的方法
    showReminderModal: crudActions.showModal,
    closeReminderModal: crudActions.closeModal,
    editReminder: crudActions.edit,
    viewReminder: crudActions.view,
    handleSaveReminder: crudActions.handleSave,
    handleUpdateReminder: crudActions.handleUpdate,
    handleDeleteReminder: crudActions.handleDelete,

    // 提醒特有的状态
    reminders,

    // 提醒特有的方法
    markReminderPaid,
    handleMarkReminderPaid,
  };
}
