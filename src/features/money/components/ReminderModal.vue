<script setup lang="ts">
import * as _ from 'es-toolkit/compat';
import z from 'zod';
import ColorSelector from '@/components/common/ColorSelector.vue';
import CurrencySelector from '@/components/common/money/CurrencySelector.vue';
import PrioritySelector from '@/components/common/PrioritySelector.vue';
import ReminderSelector from '@/components/common/ReminderSelector.vue';
import RepeatPeriodSelector from '@/components/common/RepeatPeriodSelector.vue';
import { COLORS_MAP, CURRENCY_CNY } from '@/constants/moneyConst';
import {
  PrioritySchema,
} from '@/schema/common';
import { BilReminderCreateSchema, BilReminderUpdateSchema, ReminderTypesSchema } from '@/schema/money';
import { DateUtils } from '@/utils/date';
import type { Priority, RepeatPeriod } from '@/schema/common';
import type { BilReminder, ReminderTypes } from '@/schema/money';

interface Props {
  reminder: BilReminder | null;
}

const props = defineProps<Props>();

const emit = defineEmits(['close', 'save', 'update']);

const colorNameMap = ref(COLORS_MAP);

// 假设已注入 t 函数
const { t } = useI18n();

// 响应式状态
const isSubmitting = ref(false);
const locale = ref<'zh-CN' | 'en'>('zh-CN');
const today = ref(DateUtils.getTodayDate());

// 验证错误
const validationErrors = reactive({
  name: '',
  type: '',
  amount: '',
  remindDate: '',
  repeatPeriod: '',
  priority: '',
});

const financeTypes: ReminderTypes[] = [
  ReminderTypesSchema.enum.Bill,
  ReminderTypesSchema.enum.Income,
  ReminderTypesSchema.enum.Budget,
  ReminderTypesSchema.enum.Investment,
  ReminderTypesSchema.enum.Savings,
  ReminderTypesSchema.enum.Tax,
  ReminderTypesSchema.enum.Insurance,
  ReminderTypesSchema.enum.Loan,
];

const form = reactive<BilReminder>(props.reminder ? { ...props.reminder } : getBilReminderDefault());

// 计算属性
const isFinanceType = computed(() => {
  if (ReminderTypesSchema.options.includes(form.type)) {
    return financeTypes.includes(form.type);
  }
  return false;
});

const amountPlaceholder = computed(() => {
  if (isFinanceType.value) {
    return t('validation.amountRequired');
  }
  return t('placeholders.amountOptional');
});

const descriptionPlaceholder = computed(() => {
  // 修复：正确的类型检查和动态键访问
  const placeholderKey = `placeholders.reminderDetails.${form.type}`;
  const defaultKey = 'placeholders.reminderDetails.default';

  try {
    return t(placeholderKey);
  } catch {
    return t(defaultKey);
  }
});

const isFormValid = computed(() => {
  return !!(
    form.name.trim()
    && form.type
    && form.remindDate
    && form.priority
    && !validationErrors.name
    && !validationErrors.type
    && !validationErrors.amount
    && !validationErrors.remindDate
    && !validationErrors.repeatPeriod
    && !validationErrors.priority
    && (!isFinanceType.value || (form.amount && form.amount > 0))
  );
});

// 验证方法
function validateName() {
  if (!form.name.trim()) {
    validationErrors.name = t('validation.reminderTitle');
  } else if (form.name.trim().length < 2) {
    validationErrors.name = t('validation.titleMinLength');
  } else if (form.name.trim().length > 50) {
    validationErrors.name = t('validation.titleMaxLength');
  } else {
    validationErrors.name = '';
  }
}

function validateAmount() {
  if (isFinanceType.value) {
    if (!form.amount || form.amount <= 0) {
      validationErrors.amount = t('validation.financeTypeAmount');
    } else if (form.amount > 999999999) {
      validationErrors.amount = t('validation.maxAmount');
    } else {
      validationErrors.amount = '';
    }
  } else {
    validationErrors.amount = '';
  }
}

function validateRemindDate() {
  if (!form.remindDate) {
    validationErrors.remindDate = t('validation.reminderDate');
  } else {
    const selectedDate = new Date(form.remindDate);
    form.dueAt = form.remindDate;
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (selectedDate < today) {
      validationErrors.remindDate = t('validation.dateNotPast');
    } else {
      validationErrors.remindDate = '';
    }
  }
}

// 事件处理
function handleTypeChange(value: string) {
  validationErrors.type = '';

  // 根据不同类型设置智能默认值
  switch (value) {
    case 'Bill':
      form.priority = 'High';
      form.advanceValue = 3;
      form.advanceUnit = 'days';
      form.color = '#EF4444'; // 红色
      break;
    case 'Income':
      form.priority = 'Medium';
      form.advanceValue = 1;
      form.advanceUnit = 'days';
      form.color = '#10B981'; // 绿色
      break;
    case 'Investment':
      form.priority = 'Medium';
      form.advanceValue = 1;
      form.advanceUnit = 'days';
      form.color = '#3B82F6'; // 蓝色
      break;
    case 'Health':
      form.priority = 'High';
      form.advanceValue = 1;
      form.advanceUnit = 'days';
      form.color = '#FFA000'; // 橙色
      break;
    case 'Meeting':
      form.priority = 'Medium';
      form.advanceValue = 30;
      form.advanceUnit = 'minutes';
      form.color = '#8B5CF6'; // 紫色
      break;
    case 'Birthday':
    case 'Anniversary':
      form.priority = 'Medium';
      form.advanceValue = 1;
      form.advanceUnit = 'days';
      form.color = '#EC4899'; // 粉色
      form.repeatPeriod = { type: 'Yearly', interval: 1, month: 1, day: 1 };
      break;
    case 'Exercise':
      form.priority = 'Low';
      form.advanceValue = 1;
      form.advanceUnit = 'hours';
      form.color = '#06B6D4'; // 青色
      break;
    case 'Medicine':
      form.priority = 'Urgent';
      form.advanceValue = 30;
      form.advanceUnit = 'minutes';
      form.color = '#EF4444'; // 红色
      break;
    default:
      form.priority = 'Medium';
      form.advanceValue = 1;
      form.advanceUnit = 'hours';
      break;
  }

  // 验证金额字段
  validateAmount();
}

function handleTypeValidation(isValid: boolean) {
  if (!isValid) {
    validationErrors.type = t('validation.selectReminderType');
  } else {
    validationErrors.type = '';
  }
}

function handleRepeatPeriodChange(value: RepeatPeriod) {
  // 确保 advanceValue 有值，如果为 undefined 或 null 则设为 0
  const currentAdvanceValue = form.advanceValue ?? 0;

  // 根据重复类型调整提前提醒时间的合理性
  if (value.type === 'Daily' && currentAdvanceValue > 12) {
    form.advanceValue = 1;
    form.advanceUnit = 'hours';
  } else if (value.type === 'Weekly' && currentAdvanceValue > 168) {
    // 168小时 = 7天
    form.advanceValue = 1;
    form.advanceUnit = 'days';
  } else if (value.type === 'Monthly' && currentAdvanceValue > 720) {
    // 720小时 = 30天
    form.advanceValue = 3;
    form.advanceUnit = 'days';
  }

  // 清除验证错误
  validationErrors.repeatPeriod = '';
}

function handleRepeatPeriodValidation(isValid: boolean) {
  if (!isValid) {
    validationErrors.repeatPeriod = t('validation.repeatPeriodIncomplete');
  } else {
    validationErrors.repeatPeriod = '';
  }
}

function handlePriorityChange(value: Priority) {
  validationErrors.priority = '';

  // 确保 advanceValue 有值，如果为 undefined 或 null 则设为 0
  const currentAdvanceValue = form.advanceValue ?? 0;

  // 根据优先级调整提前提醒时间的建议
  switch (value) {
    case 'Urgent':
      // 紧急事项建议提前30分钟或1小时提醒
      if (currentAdvanceValue === 0 || currentAdvanceValue > 24) {
        form.advanceValue = 1;
        form.advanceUnit = 'hours';
      }
      break;
    case 'High':
      // 高优先级建议提前几小时或1天提醒
      if (currentAdvanceValue === 0 || currentAdvanceValue < 2) {
        form.advanceValue = 3;
        form.advanceUnit = 'hours';
      }
      break;
    case 'Medium':
      // 中等优先级保持当前设置或使用默认值
      if (currentAdvanceValue === 0) {
        form.advanceValue = 1;
        form.advanceUnit = 'hours';
      }
      break;
    case 'Low':
      // 低优先级可以设置较长的提前时间
      if (currentAdvanceValue === 0) {
        form.advanceValue = 1;
        form.advanceUnit = 'days';
      }
      break;
  }
}

function handlePriorityValidation(isValid: boolean) {
  if (!isValid) {
    validationErrors.priority = t('validation.selectPriority');
  } else {
    validationErrors.priority = '';
  }
}

function closeModal() {
  emit('close');
}

async function saveReminder() {
  // 执行所有验证
  validateName();
  validateAmount();
  validateRemindDate();

  if (!isFormValid.value) {
    return;
  }

  isSubmitting.value = true;

  try {
    const defaultValues: Record<string, unknown> = {
      name: null,
      enabled: true,
      type: null,
      description: null,
      category: null,
      amount: 0,
      currency: null,
      dueAt: null,
      billDate: null,
      remindDate: null,
      repeatPeriodType: 'None',
      repeatPeriod: null,
      isPaid: false,
      isDeleted: false,
      priority: null,
      advanceValue: 0,
      advanceUnit: null,
      color: null,
      relatedTransactionSerialNum: null,
    };
    const formattedData = _.mapValues({
      name: form.name,
      enabled: form.enabled,
      type: form.type,
      description: form.description,
      category: form.category,
      amount: form.amount,
      currency: form.currency?.code || CURRENCY_CNY.code,
      dueAt: form.dueAt,
      billDate: form.billDate,
      remindDate: form.remindDate,
      repeatPeriodType: form.repeatPeriodType,
      repeatPeriod: form.repeatPeriod,
      isPaid: form.isPaid,
      priority: form.priority,
      advanceValue: form.advanceValue ?? 0,
      advanceUnit: form.advanceUnit,
      color: form.color,
      relatedTransactionSerialNum: form.relatedTransactionSerialNum,
      isDeleted: form.isDeleted,
    }, (value: unknown, key: string) => {
      if (key.endsWith('Date') || key === 'dueAt') {
        if (value) {
          const dateValue = typeof value === 'string' ?
            value :
            value instanceof Date ?
                value.toISOString() :
                String(value);
          return DateUtils.toLocalISOFromDateInput(dateValue);
        }
        return null;
      }
      // 应用默认值
      return _.defaultTo(value, defaultValues[key] ?? null);
    });
    if (props.reminder) {
      const changes = _.omitBy(formattedData, (value: unknown, key: string) =>
        _.isEqual(value, _.get(props.reminder, key)));
      // 特殊处理需要序列化为JSON的字段
      const jsonFields = [
        'repeatPeriod',
      ];
      const serializedChanges = _.mapValues(changes, (value, key) => {
        if (jsonFields.includes(key) && value !== null && value !== undefined) {
          try {
            return JSON.stringify(value);
          } catch {
            return value;
          }
        }
        return value;
      });
      if (!_.isEmpty(serializedChanges)) {
        const bilReminderUpdate = BilReminderUpdateSchema.parse(changes);
        emit('update', props.reminder.serialNum, bilReminderUpdate);
      }
    } else {
      const createBilReminder = BilReminderCreateSchema.parse(formattedData);
      emit('save', createBilReminder);
    }
    closeModal();
  } catch (err: unknown) {
    if (err instanceof z.ZodError) {
      console.error('Validation failed:', err.issues);
    } else {
      console.error('Unexpected error:', err);
    }
  } finally {
    isSubmitting.value = false;
  }
}

// 监听器
watch(
  () => props.reminder,
  newVal => {
    if (newVal) {
      const clonedReminder = JSON.parse(JSON.stringify(newVal));
      // 确保 advanceValue 有默认值，使用空值合并运算符
      clonedReminder.advanceValue = clonedReminder.advanceValue ?? 0;
      if (!clonedReminder.currency) {
        clonedReminder.currency = CURRENCY_CNY;
      }
      Object.assign(form, clonedReminder);
    }
  },
  { immediate: true, deep: true },
);

function getBilReminderDefault(): BilReminder {
  const today = DateUtils.getTodayDate();
  return {
    serialNum: '',
    name: '',
    enabled: true,
    type: ReminderTypesSchema.enum.Bill,
    description: '',
    category: 'Food',
    amount: 0,
    currency: CURRENCY_CNY,
    dueAt: DateUtils.getEndOfTodayISOWithOffset(),
    billDate: today,
    remindDate: today,
    repeatPeriodType: 'None',
    repeatPeriod: { type: 'None' } as RepeatPeriod,
    isPaid: false,
    priority: PrioritySchema.enum.Medium,
    advanceValue: 0,
    advanceUnit: 'hours',
    color: COLORS_MAP[0].code,
    relatedTransactionSerialNum: null,
    isDeleted: false,
    createdAt: '',
    updatedAt: '',

  };
}

// 监听类型变化，自动验证金额
watch(
  () => form.type,
  () => {
    nextTick(() => {
      validateAmount();
    });
  },
);

watch(() => form.repeatPeriod, repeatPeriod => {
  form.repeatPeriodType = repeatPeriod.type;
});

// 清理验证错误
watch(
  () => form.name,
  () => {
    if (validationErrors.name) {
      validateName();
    }
  },
);

watch(
  () => form.type,
  () => {
    if (isFinanceType.value) {
      form.billDate = DateUtils.getTodayDate();
    } else {
      form.billDate = null;
    }
  },
);

watch(
  () => form.remindDate,
  () => {
    if (validationErrors.remindDate) {
      validateRemindDate();
    }
  },
);

// 确保 advanceValue 始终有值
watch(
  () => form.advanceValue,
  newVal => {
    if (newVal === undefined || newVal === null) {
      form.advanceValue = 0;
    }
  },
);

watch(
  () => props.reminder,
  newVal => {
    if (newVal) {
      const clonedReminder = JSON.parse(JSON.stringify(newVal));
      if (clonedReminder.remindDate) {
        clonedReminder.remindDate = clonedReminder.remindDate.split('T')[0];
      }
      if (clonedReminder.billDate) {
        clonedReminder.billDate = clonedReminder.billDate.split('T')[0];
      }
      Object.assign(form, clonedReminder);
    }
  },
  { immediate: true, deep: true },
);
</script>

<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-lg font-semibold">
          {{ props.reminder ? t('financial.reminder.editReminder') : t('financial.reminder.addReminder') }}
        </h3>
        <button class="text-gray-500 hover:text-gray-700" @click="closeModal">
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <form @submit.prevent="saveReminder">
        <!-- 提醒标题 -->
        <div class="form-row">
          <label class="form-label">
            {{ t('financial.reminder.reminderTitle') }}
            <span class="required-asterisk" aria-label="必填">*</span>
          </label>
          <input
            v-model="form.name" type="text" required class="modal-input-select w-2/3"
            :class="{ 'border-red-500': validationErrors.name }" :placeholder="t('validation.reminderTitle')"
            @blur="validateName"
          >
        </div>
        <div v-if="validationErrors.name" class="form-error" role="alert">
          {{ validationErrors.name }}
        </div>

        <ReminderSelector
          v-model="form.type"
          :label="t('financial.reminder.reminderType')"
          :placeholder="t('common.placeholders.selectType')"
          :required="true"
          :error-message="validationErrors.type"
          :show-grouped="true"
          :show-quick-select="true"
          :show-icons="true"
          :popular-only="false"
          :locale="locale"
          width="2/3" quick-select-label="常用类型"
          :help-text="t('helpTexts.reminderType')"
          @change="handleTypeChange"
          @validate="handleTypeValidation"
        />

        <!-- 金额 -->
        <div
          v-if="isFinanceType"
          class="form-row form-row-with-margin"
        >
          <label class="form-label">
            {{ t('financial.money') }}
            <span v-if="isFinanceType" class="required-asterisk">*</span>
          </label>
          <div class="form-input-2-3">
            <div class="amount-input-group">
              <div class="amount-input">
                <input
                  v-model.number="form.amount"
                  type="number"
                  step="0.01"
                  min="0"
                  class="modal-input-select w-full"
                  :class="{ 'border-red-500': validationErrors.amount }" :placeholder="amountPlaceholder"
                  :required="isFinanceType" @blur="validateAmount"
                >
              </div>
              <div class="currency-selector">
                <CurrencySelector v-model="form.currency" width="full" />
              </div>
            </div>
          </div>
        </div>
        <!-- 账单日期 -->
        <div
          v-if="isFinanceType"
          class="form-row"
        >
          <label class="form-label">
            {{ t('date.billDate') }}
            <span class="required-asterisk" aria-label="必填">*</span>
          </label>
          <input
            v-model="form.billDate"
            type="date"
            required
            class="modal-input-select w-2/3"
            :class="{ 'border-red-500': validationErrors.remindDate }" :min="today"
            @blur="validateRemindDate"
          >
        </div>

        <!-- 提醒日期 -->
        <div class="form-row">
          <label class="form-label">
            {{ t('date.reminderDate') }}
            <span class="required-asterisk" aria-label="必填">*</span>
          </label>
          <input
            v-model="form.remindDate"
            type="date"
            required
            class="modal-input-select w-2/3"
            :class="{ 'border-red-500': validationErrors.remindDate }" :min="today"
            @blur="validateRemindDate"
          >
        </div>
        <div
          v-if="validationErrors.remindDate" class="form-error"
          role="alert"
        >
          {{ validationErrors.remindDate }}
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

        <!-- 优先级 -->
        <div class="mb-2 mt-2">
          <PrioritySelector
            v-model="form.priority" :label="t('common.misc.priority')"
            :error-message="validationErrors.priority" :locale="locale" :show-icons="true" width="2/3"
            :help-text="t('helpTexts.priority')" @change="handlePriorityChange" @validate="handlePriorityValidation"
          />
        </div>

        <!-- 提前提醒 -->
        <div class="form-row">
          <label class="form-label form-label-block">
            {{ t('financial.reminder.advanceReminder') }}
          </label>
          <div class="advance-reminder-group">
            <input
              v-model.number="form.advanceValue" type="number" min="0" max="999"
              class="modal-input-select flex-1 w-1/2" placeholder="0"
            >
            <select v-model="form.advanceUnit" class="modal-input-select">
              <option value="minutes">
                {{ t('units.minutes') }}
              </option>
              <option value="hours">
                {{ t('units.hours') }}
              </option>
              <option value="days">
                {{ t('units.days') }}
              </option>
              <option value="weeks">
                {{ t('units.weeks') }}
              </option>
            </select>
          </div>
        </div>

        <!-- 颜色选择 -->
        <div class="form-row">
          <label class="form-label">
            {{ t('common.misc.colorMark') }}
          </label>
          <ColorSelector v-model="form.color" :color-names="colorNameMap" />
        </div>

        <!-- 启用状态 -->
        <div class="checkbox-section">
          <label class="checkbox-label">
            <input v-model="form.enabled" type="checkbox" class="mr-2">
            <span class="checkbox-text">
              {{ t('financial.reminder.enabled') }}
            </span>
          </label>
        </div>

        <!-- 描述 -->
        <div class="form-textarea">
          <label class="form-label form-label-block">
            {{ t('common.misc.description') }}
            <span class="optional-text">({{ t('common.misc.optional') }})</span>
          </label>
          <textarea
            v-model="form.description" rows="3" class="modal-input-select w-full"
            :placeholder="descriptionPlaceholder" maxlength="200"
          />
          <div class="character-count">
            {{ t('common.misc.maxLength', { current: form.description?.length || 0, max: 200 }) }}
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="modal-actions">
          <button type="button" class="btn-close" :disabled="isSubmitting" @click="closeModal">
            <LucideX class="icon-btn" />
          </button>
          <button
            type="submit" class="btn-submit" :disabled="!isFormValid || isSubmitting"
            :class="{ 'opacity-50 cursor-not-allowed': !isFormValid || isSubmitting }"
          >
            <template v-if="isSubmitting">
              <div class="border-b-2 border-white rounded-full h-5 w-5 animate-spin" />
            </template>
            <template v-else>
              <LucideCheck class="icon-btn" />
            </template>
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped lang="postcss">
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

.form-label-block {
  display: block;
}

.form-input-2-3 {
  width: 66.666667%;
}

.form-textarea {
  margin-bottom: 1rem;
}

.form-error {
  font-size: 0.875rem;
  color: #dc2626;
  margin-bottom: 0.5rem;
  text-align: right;
}

/* Required asterisk */
.required-asterisk {
  color: #ef4444;
  margin-left: 0.25rem;
}

/* Amount input group */
.amount-input-group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.amount-input {
  flex: 1;
}

.currency-selector {
  flex: 1;
  margin-top: 0.5rem;
}

/* Advance reminder group */
.advance-reminder-group {
  display: flex;
  width: 66.666667%;
  align-items: center;
  gap: 0.25rem;
}

/* Checkbox section */
.checkbox-section {
  margin-bottom: 0.5rem;
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

/* Optional text */
.optional-text {
  color: #6b7280;
}

/* Character count */
.character-count {
  font-size: 0.75rem;
  color: #6b7280;
  margin-top: 0.25rem;
  text-align: right;
}

/* Submit button loading state */
.modal-btn-check:disabled {
  background-color: rgb(156 163 175);
  cursor: not-allowed;
}

/* Responsive optimization */
@media (max-width: 640px) {
  .form-row {
    flex-direction: column;
    align-items: stretch;
  }

  .form-label {
    margin-bottom: 0.25rem;
  }
}
</style>
