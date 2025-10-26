<script setup lang="ts">
import * as _ from 'es-toolkit/compat';
import { Check, X } from 'lucide-vue-next';
import z from 'zod';
import CategorySelector from '@/components/common/CategorySelector.vue';
import ColorSelector from '@/components/common/ColorSelector.vue';
import AccountSelector from '@/components/common/money/AccountSelector.vue';
import RepeatPeriodSelector from '@/components/common/RepeatPeriodSelector.vue';
import { COLORS_MAP, CURRENCY_CNY } from '@/constants/moneyConst';
import { BudgetTypeSchema } from '@/schema/common';
import { BudgetCreateSchema, BudgetScopeTypeSchema, BudgetUpdateSchema } from '@/schema/money';
import { DateUtils } from '@/utils/date';
import { deepDiff } from '@/utils/diffObject';
import { getLocalCurrencyInfo } from '../utils/money';
import type { RepeatPeriod } from '@/schema/common';
import type { Budget, BudgetCreate, BudgetUpdate } from '@/schema/money';

interface Props {
  budget: Budget | null;
}

// 定义 props
const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [budget: BudgetCreate];
  update: [serialNum: string, budget: BudgetUpdate];
}>();

const { t } = useI18n();
const colorNameMap = ref(COLORS_MAP);
const currency = ref(CURRENCY_CNY);
const categoryError = ref('');
const accountError = ref('');

// 验证错误
const validationErrors = reactive({
  name: '',
  type: '',
  amount: '',
  remindDate: '',
  repeatPeriod: '',
  priority: '',
});

const form = reactive<Budget>(props.budget ? { ...props.budget } : getDefaultBudget());
const types = Object.values(BudgetScopeTypeSchema.enum).map(type => ({
  original: type,
  snake: toCamelCase(type),
}));

function onSubmit() {
  try {
    const defaultValues: Record<string, unknown> = {
      accountSerialNum: null,
      currency: null,
      alertThreshold: null,
      budgetType: null,
      accountScope: null,
      advancedRules: null,
      currentPeriodUsed: 0,
      currentPeriodStart: null,
      progress: 0,
      linkedGoal: null,
      reminders: [],
      priority: 0,
      tags: [],
      autoRollover: false,
      rolloverHistory: [],
      sharingSettings: null,
      attachments: [],
    };

    const formattedData = _.mapValues({
      name: form.name,
      description: form.description,
      accountSerialNum: form.accountSerialNum,
      amount: form.amount,
      currency: form.currency?.code,
      repeatPeriodType: form.repeatPeriodType,
      repeatPeriod: form.repeatPeriod,
      startDate: form.startDate,
      endDate: form.endDate,
      usedAmount: form.usedAmount,
      isActive: form.isActive,
      alertEnabled: form.alertEnabled,
      alertThreshold: form.alertThreshold,
      color: form.color,
      budgetType: form.budgetType,
      budgetScopeType: form.budgetScopeType,
      categoryScope: form.categoryScope,
      accountScope: form.accountScope,
      advancedRules: form.advancedRules,
      currentPeriodUsed: form.currentPeriodUsed,
      currentPeriodStart: form.currentPeriodStart,
      progress: form.progress,
      linkedGoal: form.linkedGoal,
      reminders: form.reminders,
      priority: form.priority,
      tags: form.tags,
      autoRollover: form.autoRollover,
      rolloverHistory: form.rolloverHistory,
      sharingSettings: form.sharingSettings,
      attachments: form.attachments,
    }, (value: unknown, key: string) => {
      // 特殊处理日期字段 - 确保传入字符串
      if (key.endsWith('Date')) {
        if (value) {
          const dateValue = typeof value === 'string' ?
            value :
            value instanceof Date ?
                value.toISOString() :
                String(value);
          if (key === 'startDate') {
            return DateUtils.toLocalISOFromDateInput(dateValue);
          }
          if (key === 'endDate') {
            return DateUtils.toLocalISOFromDateInput(dateValue, true);
          }
        }
        return null;
      }
      // 应用默认值
      return _.defaultTo(value, defaultValues[key] ?? null);
    });

    // 2. 直接基于 formattedData 做类型转换和兜底（替换原 createData 的逻辑）
    if (formattedData.amount != null) formattedData.amount = Number(formattedData.amount);
    if (formattedData.usedAmount != null) formattedData.usedAmount = Number(formattedData.usedAmount);
    if (formattedData.currentPeriodUsed != null) formattedData.currentPeriodUsed = Number(formattedData.currentPeriodUsed);
    if (formattedData.progress != null) formattedData.progress = Number(formattedData.progress);
    if (formattedData.priority != null) formattedData.priority = Math.round(Number(formattedData.priority));

    // 兜底默认值（确保字段符合接口要求）
    formattedData.currentPeriodUsed = formattedData.currentPeriodUsed ?? 0;
    formattedData.progress = formattedData.progress ?? 0;
    formattedData.priority = formattedData.priority ?? 0;
    formattedData.autoRollover = formattedData.autoRollover ?? false;
    if (props.budget) {
      const changes = _.omitBy(formattedData, (value: unknown, key: string) =>
        _.isEqual(value, _.get(props.budget, key)));
      // 特殊处理需要序列化为JSON的字段
      const jsonFields = [
        'repeatPeriod',
        'alertThreshold',
        'accountScope',
        'categoryScope',
        'advancedRules',
        'reminders',
        'rolloverHistory',
        'sharingSettings',
        'attachments',
        'tags',
      ];
      const serializedChanges = _.mapValues(changes, (value, key) => {
        if (jsonFields.includes(key) && value !== null && value !== undefined) {
          try {
            return JSON.parse(JSON.stringify(value));
          } catch {
            return value;
          }
        }
        return value;
      });
      if (!_.isEmpty(serializedChanges)) {
        const updateParital = deepDiff(props.budget, formattedData, { ignoreKeys: ['repeatPeriod'] }) as BudgetUpdate;
        const budgetUpdate = BudgetUpdateSchema.parse(updateParital);
        emit('update', props.budget.serialNum, budgetUpdate);
      }
    } else {
      const budgetCreate = BudgetCreateSchema.parse(formattedData);
      emit('save', budgetCreate);
    }
    closeModal();
  } catch (err: unknown) {
    if (err instanceof z.ZodError) {
      console.error('Validation failed:', err.issues);
    } else {
      console.error('Unexpected error:', err);
    }
  }
}

function handleRepeatPeriodChange(_value: RepeatPeriod) {
  validationErrors.repeatPeriod = '';
}
function handleAccountValidation(isValid: boolean) {
  accountError.value = isValid ? '' : '请至少选择一个账户';
}

function handleRepeatPeriodValidation(isValid: boolean) {
  if (!isValid) {
    validationErrors.repeatPeriod = t('validation.repeatPeriodIncomplete');
  } else {
    validationErrors.repeatPeriod = '';
  }
}

function getDefaultBudget(): Budget {
  const day = DateUtils.getTodayDate();
  return {
    serialNum: '',
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
    alertEnabled: false,
    alertThreshold: null,
    color: COLORS_MAP[0].code,
    account: null,
    createdAt: DateUtils.getLocalISODateTimeWithOffset(),
    updatedAt: null,
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
    budgetScopeType: BudgetScopeTypeSchema.enum.Category,
    accountScope: null,
    categoryScope: [],
    advancedRules: null,
  };
}

function handleCategoryValidation(isValid: boolean) {
  if (!isValid) {
    categoryError.value = '请至少选择一个分类';
  } else {
    categoryError.value = '';
  }
}

function toCamelCase(str: string) {
  return str.charAt(0).toLowerCase() + str.slice(1);
}

function closeModal() {
  emit('close');
}

watch(
  () => props.budget,
  newVal => {
    if (newVal) {
      const clonedAccount = JSON.parse(JSON.stringify(newVal));
      if (clonedAccount.startDate) {
        clonedAccount.startDate = clonedAccount.startDate.split('T')[0];
      }
      if (clonedAccount.endDate) {
        clonedAccount.endDate = clonedAccount.endDate.split('T')[0];
      }
      Object.assign(form, clonedAccount);
    }
  },
  { immediate: true, deep: true },
);

watch(() => form.repeatPeriod, repeatPeriodType => {
  form.repeatPeriodType = repeatPeriodType.type;
});
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

onMounted(async () => {
  const cny = await getLocalCurrencyInfo();
  currency.value = cny;
});
</script>

<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="modal-header">
        <h3 class="modal-title">
          {{ props.budget ? t('financial.budget.editBudget') : t('financial.budget.addBudget') }}
        </h3>
        <button class="modal-close-btn" @click="closeModal">
          <svg class="close-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <form @submit.prevent="onSubmit">
        <div class="form-row">
          <label class="form-label">
            {{ t('financial.budget.budgetName') }}
          </label>
          <input
            v-model="form.name" type="text" required class="modal-input-select w-2/3"
            :placeholder="t('validation.budgetName')"
          >
        </div>

        <div class="form-row">
          <label class="form-label">
            {{ t('financial.budget.budgetScopeType') }}
          </label>
          <select v-model="form.budgetScopeType" required class="modal-input-select w-2/3">
            <option
              v-for="ty in types"
              :key="ty.original"
              :value="ty.original"
            >
              {{ t(`financial.budgetScopeTypes.${ty.snake}`) }}
            </option>
          </select>
        </div>

        <div
          v-if="form.budgetScopeType === 'Category' || form.budgetScopeType === 'Hybrid'"
        >
          <CategorySelector
            v-model="form.categoryScope"
            :required="true"
            label="预算类别"
            placeholder="请选择分类"
            help-text="选择适用于此预算的分类"
            :error-message="categoryError"
            @validate="handleCategoryValidation"
          />
        </div>

        <div
          v-if="form.budgetScopeType === 'Account'"
        >
          <AccountSelector
            v-model="form.accountSerialNum"
            :required="true"
            label="账户选择"
            placeholder="请选择账户"
            help-text="选择适用于此预算的账户"
            @validate="handleAccountValidation"
          />
        </div>

        <div class="form-row">
          <label class="form-label">
            {{ t('financial.budget.budgetAmount') }}
          </label>
          <input
            v-model.number="form.amount" type="number" step="0.01" required class="modal-input-select w-2/3"
            placeholder="0.00"
          >
        </div>

        <!-- 重复频率  -->
        <RepeatPeriodSelector
          v-model="form.repeatPeriod"
          :label="t('date.repeat.frequency')"
          :error-message="validationErrors.repeatPeriod"
          :help-text="t('helpTexts.repeatPeriod')"
          @change="handleRepeatPeriodChange"
          @validate="handleRepeatPeriodValidation"
        />

        <div class="form-row form-row-with-margin">
          <label class="form-label">
            {{ t('date.startDate') }}
          </label>
          <input v-model="form.startDate" type="date" required class="modal-input-select w-2/3">
        </div>

        <div class="form-row">
          <label class="form-label">
            {{ t('date.endDate') }}
          </label>
          <input v-model="form.endDate" type="date" class="modal-input-select w-2/3">
        </div>

        <div class="form-row">
          <label class="form-label">
            {{ t('common.misc.color') }}
          </label>
          <ColorSelector
            v-model="form.color"
            :color-names="colorNameMap"
            :extended="true"
            :show-categories="true"
            :show-custom-color="true"
          />
        </div>
        <div class="alert-section">
          <!-- 左边复选框 -->
          <div class="alert-checkbox">
            <label class="checkbox-label">
              <input
                v-model="form.alertEnabled"
                type="checkbox"
                class="checkbox-radius"
              >
              <span class="checkbox-text">
                {{ t('financial.budget.overBudgetAlert') }}
              </span>
            </label>
          </div>

          <!-- 右边 阈值设置 -->
          <div v-if="form.alertEnabled && form.alertThreshold" class="threshold-settings">
            <!-- 阈值类型选择 -->
            <select
              v-model="form.alertThreshold.type"
              class="modal-input-select w-2/3"
            >
              <option value="Percentage">
                {{ t('financial.budget.threshold.percentage') }}
              </option>
              <option value="FixedAmount">
                {{ t('financial.budget.threshold.fixedAmount') }}
              </option>
            </select>

            <!-- 阈值输入框 -->
            <input
              v-model.number="form.alertThreshold.value"
              type="number"
              class="modal-input-select w-1/3"
              :min="form.alertThreshold.type === 'Percentage' ? 0 : 1"
              :max="form.alertThreshold.type === 'Percentage' ? 100 : undefined"
              :placeholder="form.alertThreshold.type === 'Percentage' ? '80%' : '100.00'"
            >
          </div>
        </div>
        <div class="form-textarea">
          <textarea
            v-model="form.description" rows="3" class="modal-input-select w-full"
            :placeholder="t('placeholders.budgetDescription')"
          />
        </div>

        <div class="modal-actions">
          <button type="button" class="btn-close" @click="closeModal">
            <X class="icon-btn" />
          </button>
          <button type="submit" class="btn-submit">
            <Check class="icon-btn" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
/* Form Layout */
.form-row {
  margin-bottom: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.form-row-with-margin {
  margin-top: 0.5rem;
}

.form-label {
  font-size: 0.875rem;
  color: #374151;
  font-weight: 500;
  margin-bottom: 0.5rem;
}

.form-textarea {
  margin-bottom: 0.5rem;
}

/* Alert Section */
.alert-section {
  margin-bottom: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.alert-checkbox {
  width: 33.333333%;
}

.checkbox-label {
  display: flex;
  align-items: center;
}

.checkbox-text {
  font-size: 0.875rem;
  color: #374151;
  font-weight: 500;
}

.threshold-settings {
  display: flex;
  gap: 0.5rem;
  width: 66.666667%;
  align-items: center;
}

/* Modal Header */
.modal-header {
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-title {
  font-size: 1.125rem;
  font-weight: 600;
}

.modal-close-btn {
  color: #6b7280;
  transition: color 0.2s ease-in-out;
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.25rem;
}

.modal-close-btn:hover {
  color: #374151;
}

.close-icon {
  height: 1.5rem;
  width: 1.5rem;
}
</style>
