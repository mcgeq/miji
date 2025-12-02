import { COLORS_MAP, CURRENCY_CNY } from '@/constants/moneyConst';
import { getLocalCurrencyInfo } from '@/features/money/utils/money';
import { BudgetTypeSchema } from '@/schema/common';
import { BudgetScopeTypeSchema } from '@/schema/money';
import { useCategoryStore } from '@/stores/money';
import { DateUtils } from '@/utils/date';
import type { RepeatPeriod } from '@/schema/common';
import type { Budget } from '@/schema/money';

/**
 * 预算表单通用逻辑 Composable
 */
export function useBudgetForm(initialBudget?: Budget | null) {
  const { t } = useI18n();

  // 基础状态
  const colorNameMap = ref(COLORS_MAP);
  const currency = ref(CURRENCY_CNY);
  const categoryError = ref('');
  const accountError = ref('');
  const isSubmitting = ref(false);

  // 验证错误
  const validationErrors = reactive({
    name: '',
    type: '',
    amount: '',
    remindDate: '',
    repeatPeriod: '',
    priority: '',
  });

  // 默认预算数据
  function getDefaultBudget(): Omit<Budget, 'serialNum' | 'account' | 'createdAt' | 'updatedAt'> {
    const day = DateUtils.getTodayDate();
    return {
      accountSerialNum: null,
      name: '',
      description: '',
      amount: 0,
      currency: currency.value,
      repeatPeriodType: 'None',
      repeatPeriod: { type: 'None' },
      startDate: day,
      endDate: DateUtils.addDays(day, 30),
      usedAmount: 0,
      isActive: true,
      alertEnabled: true,
      alertThreshold: { type: 'Percentage', value: 80 },
      color: COLORS_MAP[0].code,
      currentPeriodUsed: 0,
      currentPeriodStart: DateUtils.getTodayDate(),
      budgetType: BudgetTypeSchema.enum.Standard,
      progress: 0,
      linkedGoal: null,
      reminders: [],
      priority: 0,
      tags: [],
      autoRollover: false,
      rolloverHistory: [],
      sharingSettings: { sharedWith: [], permissionLevel: 'ViewOnly' },
      attachments: [],
      budgetScopeType: BudgetScopeTypeSchema.enum.Account,
      accountScope: null,
      categoryScope: [],
      advancedRules: null,
    };
  }

  // 表单数据
  const form = reactive(initialBudget ? { ...initialBudget } : getDefaultBudget());

  // 范围类型选项
  const scopeTypes = computed(() =>
    Object.values(BudgetScopeTypeSchema.enum).map(type => ({
      original: type,
      snake: toCamelCase(type),
    })),
  );

  // 表单验证
  const isFormValid = computed(() => {
    if (!form.name || form.amount <= 0) return false;
    if (
      form.budgetScopeType === 'Category' &&
      (!form.categoryScope || form.categoryScope.length === 0)
    ) {
      return false;
    }
    if (form.budgetScopeType === 'Account' && !form.accountSerialNum) {
      return false;
    }
    return true;
  });

  // 验证处理函数
  function handleCategoryValidation(isValid: boolean) {
    categoryError.value = isValid ? '' : '请至少选择一个分类';
  }

  function handleAccountValidation(isValid: boolean) {
    accountError.value = isValid ? '' : '请至少选择一个账户';
  }

  function handleRepeatPeriodValidation(isValid: boolean) {
    validationErrors.repeatPeriod = isValid ? '' : t('validation.repeatPeriodIncomplete');
  }

  function handleRepeatPeriodChange(_value: RepeatPeriod) {
    validationErrors.repeatPeriod = '';
  }

  // 辅助函数
  function toCamelCase(str: string) {
    return str.charAt(0).toLowerCase() + str.slice(1);
  }

  // 初始化
  onMounted(async () => {
    // 加载货币信息
    const cny = await getLocalCurrencyInfo();
    currency.value = cny;

    // 加载分类数据
    const categoryStore = useCategoryStore();
    if (categoryStore.categories.length === 0) {
      await categoryStore.fetchCategories();
    }
  });

  // 监听重复周期变化
  watch(
    () => form.repeatPeriod,
    repeatPeriodType => {
      form.repeatPeriodType = repeatPeriodType.type;
    },
  );

  // 监听预警开关
  watch(
    () => form.alertEnabled,
    enabled => {
      if (enabled && !form.alertThreshold) {
        form.alertThreshold = { type: 'Percentage', value: 80 };
      }
      if (!enabled) {
        form.alertThreshold = null;
      }
    },
  );

  // 格式化表单数据用于提交
  function formatFormData() {
    return {
      name: form.name,
      description: form.description || '',
      accountSerialNum: form.accountSerialNum,
      amount: Number(form.amount),
      currency: form.currency?.code || 'CNY',
      repeatPeriodType: form.repeatPeriodType,
      repeatPeriod: form.repeatPeriod,
      startDate: DateUtils.toLocalISOFromDateInput(form.startDate),
      endDate: form.endDate ? DateUtils.toLocalISOFromDateInput(form.endDate, true) : '',
      usedAmount: form.usedAmount || 0,
      isActive: form.isActive,
      alertEnabled: form.alertEnabled,
      alertThreshold: form.alertEnabled ? form.alertThreshold : undefined,
      color: form.color,
      budgetType: form.budgetType,
      budgetScopeType: form.budgetScopeType,
      categoryScope: form.categoryScope,
      accountScope: form.accountScope,
      advancedRules: form.advancedRules,
      currentPeriodUsed: form.currentPeriodUsed || 0,
      currentPeriodStart: form.currentPeriodStart,
      progress: form.progress || 0,
      linkedGoal: form.linkedGoal,
      reminders: form.reminders || [],
      priority: form.priority || 0,
      tags: form.tags || [],
      autoRollover: form.autoRollover || false,
      rolloverHistory: form.rolloverHistory || [],
      sharingSettings: form.sharingSettings,
      attachments: form.attachments || [],
    };
  }

  return {
    // 状态
    form,
    colorNameMap,
    currency,
    categoryError,
    accountError,
    isSubmitting,
    validationErrors,

    // 计算属性
    scopeTypes,
    isFormValid,

    // 方法
    handleCategoryValidation,
    handleAccountValidation,
    handleRepeatPeriodValidation,
    handleRepeatPeriodChange,
    formatFormData,
    getDefaultBudget,
  };
}
