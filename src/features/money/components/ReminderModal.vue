<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import ColorSelector from '@/components/common/ColorSelector.vue';
import CurrencySelector from '@/components/common/money/CurrencySelector.vue';
import PrioritySelector from '@/components/common/PrioritySelector.vue';
import ReminderSelector from '@/components/common/ReminderSelector.vue';
import RepeatPeriodSelector from '@/components/common/RepeatPeriodSelector.vue';
import { COLORS_MAP, CURRENCY_CNY } from '@/constants/moneyConst';
import {
  CategorySchema,

  PrioritySchema,
  ReminderTypeSchema,
} from '@/schema/common';
import { DateUtils } from '@/utils/date';
import { uuid } from '@/utils/uuid';
import type { Priority, RepeatPeriod } from '@/schema/common';
import type { BilReminder } from '@/schema/money';

const props = defineProps<Props>();

const emit = defineEmits(['close', 'save', 'update']);

const colorNameMap = ref(COLORS_MAP);

interface Props {
  reminder: BilReminder | null;
}

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

// 表单数据
const reminder = props.reminder || {
  serialNum: '',
  name: '',
  enabled: true,
  type: ReminderTypeSchema.enum.ResetReminder,
  description: '',
  category: CategorySchema.enum.Food,
  amount: 0,
  currency: CURRENCY_CNY,
  dueDate: '',
  billDate: '',
  remindDate: '',
  repeatPeriod: { type: 'None' } as RepeatPeriod,
  isPaid: false,
  priority: PrioritySchema.enum.Medium,
  advanceValue: 0,
  advanceUnit: 'hours',
  color: COLORS_MAP[0].code,
  relatedTransactionSerialNum: '',
  createdAt: '',
  updatedAt: '',
};

const form = reactive<BilReminder>({
  serialNum: reminder.serialNum,
  name: reminder.name,
  enabled: reminder.enabled,
  type: reminder.type,
  description: reminder.description,
  category: reminder.category,
  amount: reminder.amount,
  currency: reminder.currency,
  dueDate: reminder.dueDate,
  billDate: reminder.billDate,
  remindDate: reminder.remindDate,
  repeatPeriod: reminder.repeatPeriod,
  isPaid: reminder.isPaid,
  priority: reminder.priority,
  advanceValue: reminder.advanceValue ?? 0,
  advanceUnit: reminder.advanceUnit,
  color: reminder.color,
  relatedTransactionSerialNum: reminder.relatedTransactionSerialNum,
  createdAt: reminder.createdAt,
  updatedAt: reminder.updatedAt,
});

// 计算属性
const isFinanceType = computed(() => {
  const financeTypes = [
    'Bill',
    'Income',
    'Budget',
    'Investment',
    'Savings',
    'Tax',
    'Insurance',
    'Loan',
  ];
  return financeTypes.includes(form.type);
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
    const reminderData = {
      ...form,
      serialNum: props.reminder?.serialNum || uuid(38),
      createdAt: props.reminder?.createdAt || DateUtils.getLocalISODateTimeWithOffset(),
      updatedAt: DateUtils.getLocalISODateTimeWithOffset(),
      advanceValue: form.advanceValue || 0, // 确保不为undefined
    };

    emit('save', reminderData);
    closeModal();
  } catch (error) {
    console.error(t('messages.saveFailed'), error);
    // 可以添加错误提示
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
      Object.assign(form, clonedReminder);
    }
  },
  { immediate: true, deep: true },
);

// 监听类型变化，自动验证金额
watch(
  () => form.type,
  () => {
    nextTick(() => {
      validateAmount();
    });
  },
);

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
        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium dark:text-gray-300">
            {{ t('financial.reminder.reminderTitle') }}
            <span class="ml-1 text-red-500" aria-label="必填">*</span>
          </label>
          <input
            v-model="form.name" type="text" required class="w-2/3 modal-input-select"
            :class="{ 'border-red-500': validationErrors.name }" :placeholder="t('validation.reminderTitle')"
            @blur="validateName"
          >
        </div>
        <div v-if="validationErrors.name" class="mb-2 text-right text-sm text-red-600 dark:text-red-400" role="alert">
          {{ validationErrors.name }}
        </div>

        <ReminderSelector
          v-model="form.type" :label="t('financial.reminder.reminderType')"
          :placeholder="t('common.placeholders.selectType')" :required="true" :error-message="validationErrors.type"
          :show-grouped="true" :show-quick-select="true" :show-icons="true" :popular-only="false" :locale="locale"
          width="2/3" quick-select-label="常用类型" :help-text="t('helpTexts.reminderType')" @change="handleTypeChange"
          @validate="handleTypeValidation"
        />

        <!-- 金额 -->
        <div class="mb-2 mt-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium dark:text-gray-300">
            {{ t('financial.money') }}
            <span v-if="isFinanceType" class="ml-1 text-blue-500">*</span>
          </label>
          <div class="w-2/3">
            <div class="flex items-center space-x-2">
              <div class="flex-1">
                <input
                  v-model.number="form.amount" type="number" step="0.01" min="0" class="w-full modal-input-select"
                  :class="{ 'border-red-500': validationErrors.amount }" :placeholder="amountPlaceholder"
                  :required="isFinanceType" @blur="validateAmount"
                >
              </div>
              <div class="mt-2 flex-1">
                <CurrencySelector v-model="form.currency" width="full" />
              </div>
            </div>
          </div>
        </div>
        <div v-if="validationErrors.amount" class="mb-2 text-right text-sm text-red-600 dark:text-red-400" role="alert">
          {{ validationErrors.amount }}
        </div>

        <!-- 提醒日期 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium dark:text-gray-300">
            {{ t('date.reminderDate') }}
            <span class="ml-1 text-red-500" aria-label="必填">*</span>
          </label>
          <input
            v-model="form.remindDate" type="date" required class="w-2/3 modal-input-select"
            :class="{ 'border-red-500': validationErrors.remindDate }" :min="today" @blur="validateRemindDate"
          >
        </div>
        <div
          v-if="validationErrors.remindDate" class="mb-2 text-right text-sm text-red-600 dark:text-red-400"
          role="alert"
        >
          {{ validationErrors.remindDate }}
        </div>

        <!-- 重复频率  -->
        <RepeatPeriodSelector
          v-model="form.repeatPeriod" :label="t('date.repeat.frequency')"
          :error-message="validationErrors.repeatPeriod" :help-text="t('helpTexts.repeatPeriod')"
          @change="handleRepeatPeriodChange" @validate="handleRepeatPeriodValidation"
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
        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 block text-sm text-gray-700 font-medium dark:text-gray-300">
            {{ t('financial.reminder.advanceReminder') }}
          </label>
          <div class="w-2/3 flex items-center space-x-1">
            <input
              v-model.number="form.advanceValue" type="number" min="0" max="999"
              class="w-1/2 flex-1 modal-input-select" placeholder="0"
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
        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium dark:text-gray-300">
            {{ t('common.misc.colorMark') }}
          </label>
          <ColorSelector v-model="form.color" :color-names="colorNameMap" />
        </div>

        <!-- 启用状态 -->
        <div class="mb-2">
          <label class="flex items-center">
            <input v-model="form.enabled" type="checkbox" class="mr-2">
            <span class="text-sm text-gray-700 font-medium dark:text-gray-300">
              {{ t('financial.reminder.enabled') }}
            </span>
          </label>
        </div>

        <!-- 描述 -->
        <div class="mb-4">
          <label class="mb-2 block text-sm text-gray-700 font-medium dark:text-gray-300">
            {{ t('common.misc.description') }}
            <span class="text-gray-500">({{ t('common.misc.optional') }})</span>
          </label>
          <textarea
            v-model="form.description" rows="3" class="w-full modal-input-select"
            :placeholder="descriptionPlaceholder" maxlength="200"
          />
          <div class="mt-1 text-right text-xs text-gray-500 dark:text-gray-400">
            {{ t('common.misc.maxLength', { current: form.description?.length || 0, max: 200 }) }}
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="flex justify-center space-x-3">
          <button type="button" class="modal-btn-x" :disabled="isSubmitting" @click="closeModal">
            <X class="wh-5" />
          </button>
          <button
            type="submit" class="modal-btn-check" :disabled="!isFormValid || isSubmitting"
            :class="{ 'opacity-50 cursor-not-allowed': !isFormValid || isSubmitting }"
          >
            <template v-if="isSubmitting">
              <div class="h-5 w-5 animate-spin border-b-2 border-white rounded-full" />
            </template>
            <template v-else>
              <Check class="wh-5" />
            </template>
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 自定义样式 */
.modal-mask-window-money {
  max-height: 90vh;
  overflow-y: auto;
}

/* 改善表单布局 */
.modal-input-select:focus {
  @apply ring-2 ring-blue-400 ring-opacity-50 border-blue-500;
}

/* 错误状态样式 */
.border-red-500:focus {
  @apply ring-2 ring-red-400 ring-opacity-50 border-red-500;
}

/* 提交按钮加载状态 */
.modal-btn-check:disabled {
  background-color: rgb(156 163 175);
  cursor: not-allowed;
}

/* 响应式优化 */
@media (max-width: 640px) {
  .mb-2 .flex {
    flex-direction: column;
    align-items: stretch;
  }

  .mb-2 label {
    margin-bottom: 0.25rem;
  }
}
</style>
