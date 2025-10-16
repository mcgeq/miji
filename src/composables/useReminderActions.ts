import { ref } from 'vue';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type {
  BilReminder,
  BilReminderCreate,
  BilReminderUpdate,
} from '@/schema/money';

export function useReminderActions() {
  const moneyStore = useMoneyStore();

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

  // 保存提醒
  async function saveReminder(reminder: BilReminderCreate) {
    try {
      await moneyStore.createReminder(reminder);
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
        await moneyStore.updateReminder(serialNum, reminder);
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

  // 加载提醒列表
  async function loadReminders() {
    try {
      reminders.value = await moneyStore.getAllReminders();
      return true;
    } catch (err) {
      Lg.e('loadReminders', err);
      return false;
    }
  }

  return {
    // 状态
    showReminder,
    selectedReminder,
    reminders,

    // 方法
    showReminderModal,
    closeReminderModal,
    saveReminder,
    updateReminder,
    loadReminders,
  };
}
