import { ref } from 'vue';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type {
  Budget,
  BudgetCreate,
  BudgetUpdate,
} from '@/schema/money';

export function useBudgetActions() {
  const moneyStore = useMoneyStore();

  const showBudget = ref(false);
  const selectedBudget = ref<Budget | null>(null);
  const budgets = ref<Budget[]>([]);

  // 显示预算模态框
  function showBudgetModal() {
    selectedBudget.value = null;
    showBudget.value = true;
  }

  // 关闭预算模态框
  function closeBudgetModal() {
    showBudget.value = false;
    selectedBudget.value = null;
  }

  // 保存预算
  async function saveBudget(budget: BudgetCreate) {
    try {
      await moneyStore.createBudget(budget);
      toast.success('添加成功');
      closeBudgetModal();
      return true;
    } catch (err) {
      Lg.e('saveBudget', err);
      toast.error('保存失败');
      return false;
    }
  }

  // 更新预算
  async function updateBudget(serialNum: string, budget: BudgetUpdate) {
    try {
      if (selectedBudget.value) {
        await moneyStore.updateBudget(serialNum, budget);
        toast.success('更新成功');
        closeBudgetModal();
        return true;
      }
      return false;
    } catch (err) {
      Lg.e('updateBudget', err);
      toast.error('保存失败');
      return false;
    }
  }

  // 加载预算列表
  async function loadBudgets() {
    try {
      budgets.value = moneyStore.budgetsPaged.rows;
      if (budgets.value.length === 0) {
        await moneyStore.updateBudgets(true);
        budgets.value = moneyStore.budgetsPaged.rows;
      }
      return true;
    } catch (err) {
      Lg.e('loadBudgets', err);
      return false;
    }
  }

  return {
    // 状态
    showBudget,
    selectedBudget,
    budgets,

    // 方法
    showBudgetModal,
    closeBudgetModal,
    saveBudget,
    updateBudget,
    loadBudgets,
  };
}
