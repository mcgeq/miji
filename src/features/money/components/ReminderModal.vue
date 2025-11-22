<script setup lang="ts">
import * as _ from 'es-toolkit/compat';
import z from 'zod';
import BaseModal from '@/components/common/BaseModal.vue';
import ColorSelector from '@/components/common/ColorSelector.vue';
import DateTimePicker from '@/components/common/DateTimePicker.vue';
import FormRow from '@/components/common/FormRow.vue';
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

// 合并后的提醒方式（系统=desktop/mobile 二合一），其余渠道占位
const methodsState = reactive({
  system: props.reminder?.reminderMethods
    ? !!(props.reminder?.reminderMethods.desktop || props.reminder?.reminderMethods.mobile)
    : true,
  email: !!props.reminder?.reminderMethods?.email,
  sms: !!props.reminder?.reminderMethods?.sms,
});

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

// 处理 snoozeUntil 的 Date 对象转换
const snoozeUntilDate = computed({
  get: () => {
    if (!form.snoozeUntil) return null;
    try {
      const date = new Date(form.snoozeUntil);
      return Number.isNaN(date.getTime()) ? null : date;
    } catch {
      return null;
    }
  },
  set: (value: Date | null) => {
    if (value) {
      // 直接使用 ISO 字符串格式，不需要转换
      form.snoozeUntil = value.toISOString();
    } else {
      form.snoozeUntil = null;
    }
  },
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
      form.color = 'var(--color-error)'; // 红色
      break;
    case 'Income':
      form.priority = 'Medium';
      form.advanceValue = 1;
      form.advanceUnit = 'days';
      form.color = 'var(--color-success)'; // 绿色
      break;
    case 'Investment':
      form.priority = 'Medium';
      form.advanceValue = 1;
      form.advanceUnit = 'days';
      form.color = 'var(--color-info)'; // 蓝色
      break;
    case 'Health':
      form.priority = 'High';
      form.advanceValue = 1;
      form.advanceUnit = 'days';
      form.color = 'var(--color-warning)'; // 橙色
      break;
    case 'Meeting':
      form.priority = 'Medium';
      form.advanceValue = 30;
      form.advanceUnit = 'minutes';
      form.color = 'var(--color-purple-500)'; // 紫色
      break;
    case 'Birthday':
    case 'Anniversary':
      form.priority = 'Medium';
      form.advanceValue = 1;
      form.advanceUnit = 'days';
      form.color = 'var(--color-pink-500)'; // 粉色
      form.repeatPeriod = { type: 'Yearly', interval: 1, month: 1, day: 1 };
      break;
    case 'Exercise':
      form.priority = 'Low';
      form.advanceValue = 1;
      form.advanceUnit = 'hours';
      form.color = 'var(--color-cyan-500)'; // 青色
      break;
    case 'Medicine':
      form.priority = 'Urgent';
      form.advanceValue = 30;
      form.advanceUnit = 'minutes';
      form.color = 'var(--color-error)'; // 红色
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
      // 新增高级提醒功能字段默认值
      lastReminderSentAt: null,
      reminderFrequency: null,
      snoozeUntil: null,
      reminderMethods: null,
      escalationEnabled: false,
      escalationAfterHours: 24,
      timezone: null,
      smartReminderEnabled: false,
      autoReschedule: false,
      paymentReminderEnabled: false,
      batchReminderId: null,
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
      // 新增高级提醒功能字段
      lastReminderSentAt: form.lastReminderSentAt,
      reminderFrequency: form.reminderFrequency,
      snoozeUntil: form.snoozeUntil,
      reminderMethods: {
        desktop: methodsState.system,
        mobile: methodsState.system,
        email: methodsState.email,
        sms: methodsState.sms,
      },
      escalationEnabled: form.escalationEnabled,
      escalationAfterHours: form.escalationAfterHours,
      timezone: form.timezone,
      smartReminderEnabled: form.smartReminderEnabled,
      autoReschedule: form.autoReschedule,
      paymentReminderEnabled: form.paymentReminderEnabled,
      batchReminderId: form.batchReminderId,
    }, (value: unknown, key: string) => {
      if (key.endsWith('Date') || key === 'dueAt' || key === 'snoozeUntil') {
        if (value) {
          // snoozeUntil 已经是 ISO 格式，不需要转换
          if (key === 'snoozeUntil') {
            return value;
          }

          // 其他日期字段需要格式化
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
      methodsState.system = !!(clonedReminder.reminderMethods?.desktop || clonedReminder.reminderMethods?.mobile);
      methodsState.email = !!clonedReminder.reminderMethods?.email;
      methodsState.sms = !!clonedReminder.reminderMethods?.sms;
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
    // 新增高级提醒功能字段
    lastReminderSentAt: null,
    reminderFrequency: null,
    snoozeUntil: null,
    reminderMethods: null,
    escalationEnabled: false,
    escalationAfterHours: 24,
    timezone: null,
    smartReminderEnabled: false,
    autoReschedule: false,
    paymentReminderEnabled: false,
    batchReminderId: null,
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
  <BaseModal
    :title="props.reminder ? t('financial.reminder.editReminder') : t('financial.reminder.addReminder')"
    size="md"
    :confirm-loading="isSubmitting"
    @close="closeModal"
    @confirm="saveReminder"
  >
    <form @submit.prevent="saveReminder">
      <!-- 提醒标题 -->
      <FormRow
        :label="t('financial.reminder.reminderTitle')"
        required
        :error="validationErrors.name"
      >
        <input
          v-model="form.name" type="text" required class="modal-input-select w-full"
          :class="{ 'border-red-500': validationErrors.name }" :placeholder="t('validation.reminderTitle')"
          @blur="validateName"
        >
      </FormRow>

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
      <FormRow
        v-if="isFinanceType"
        :label="t('date.billDate')"
        required
      >
        <input
          v-model="form.billDate"
          type="date"
          required
          class="modal-input-select w-full"
          :class="{ 'border-red-500': validationErrors.remindDate }" :min="today"
          @blur="validateRemindDate"
        >
      </FormRow>

      <!-- 提醒日期 -->
      <FormRow
        :label="t('date.reminderDate')"
        required
        :error="validationErrors.remindDate"
      >
        <input
          v-model="form.remindDate"
          type="date"
          required
          class="modal-input-select w-full"
          :class="{ 'border-red-500': validationErrors.remindDate }" :min="today"
          @blur="validateRemindDate"
        >
      </FormRow>

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

      <!-- 提醒频率 -->
      <FormRow :label="t('financial.reminder.frequency')" optional>
        <select v-model="form.reminderFrequency" class="modal-input-select w-full">
          <option value="once">
            {{ t('common.frequency.once') }}
          </option>
          <option value="15m">
            {{ t('common.frequency.q15m') }}
          </option>
          <option value="1h">
            {{ t('common.frequency.hourly') }}
          </option>
          <option value="1d">
            {{ t('common.frequency.daily') }}
          </option>
        </select>
      </FormRow>

      <!-- 稍后提醒（打盹） -->
      <div class="form-row">
        <label class="form-label">
          {{ t('financial.reminder.snoozeUntil') }}
        </label>
        <DateTimePicker
          v-model="snoozeUntilDate"
          class="w-2/3"
          :placeholder="t('common.selectDate')"
        />
      </div>

      <!-- 提醒方式（系统合并） -->
      <div class="form-row">
        <label class="form-label form-label-block">{{ t('financial.reminder.methods') }}</label>
        <div class="form-input-2-3">
          <label class="checkbox-label"><input v-model="methodsState.system" type="checkbox" class="mr-2">系统</label>
          <div class="mt-1 flex gap-2">
            <label class="checkbox-label"><input v-model="methodsState.email" type="checkbox" class="mr-1">邮件</label>
            <label class="checkbox-label"><input v-model="methodsState.sms" type="checkbox" class="mr-1">短信</label>
          </div>
        </div>
      </div>

      <!-- 高级设置（可折叠） -->
      <details class="mt-2 mb-2">
        <summary class="form-label">
          {{ t('financial.reminder.advancedSettings') }}
        </summary>
        <div class="mt-2 flex flex-col gap-2">
          <label class="checkbox-label"><input v-model="form.escalationEnabled" type="checkbox" class="mr-2">升级提醒</label>
          <div class="form-row">
            <label class="form-label">升级间隔(小时)</label>
            <input v-model.number="form.escalationAfterHours" type="number" min="1" class="modal-input-select w-2/3">
          </div>
          <label class="checkbox-label"><input v-model="form.smartReminderEnabled" type="checkbox" class="mr-2">智能提醒</label>
          <label class="checkbox-label"><input v-model="form.autoReschedule" type="checkbox" class="mr-2">自动顺延</label>
          <label class="checkbox-label"><input v-model="form.paymentReminderEnabled" type="checkbox" class="mr-2">支付提醒</label>
          <div class="form-row">
            <label class="form-label">时区</label>
            <input v-model="form.timezone" type="text" class="modal-input-select w-2/3" placeholder="例如: Asia/Shanghai">
          </div>
          <div v-if="form.lastReminderSentAt" class="form-row">
            <label class="form-label">上次提醒时间</label>
            <input class="modal-input-select w-2/3" :value="form.lastReminderSentAt" readonly>
          </div>
        </div>
      </details>

      <!-- 颜色选择 -->
      <FormRow :label="t('common.misc.colorMark')" optional>
        <ColorSelector
          v-model="form.color"
          width="full"
          :color-names="colorNameMap"
          :extended="true"
          :show-categories="true"
          :show-custom-color="true"
          :show-random-button="true"
        />
      </FormRow>

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
        <textarea
          v-model="form.description" rows="3" class="modal-input-select w-full"
          :placeholder="descriptionPlaceholder" maxlength="200"
        />
        <div class="character-count">
          {{ t('common.misc.maxLength', { current: form.description?.length || 0, max: 200 }) }}
        </div>
      </div>
    </form>
  </BaseModal>
</template>

<style scoped lang="postcss">
/* Form Layout */
.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
  gap: 1rem;
}

.form-row-with-margin {
  margin-top: 0.5rem;
}

.form-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
  margin-bottom: 0;
  margin-right: 0;
  flex: 0 0 6rem;
  width: 6rem;
  min-width: 6rem;
  max-width: 6rem;
  white-space: nowrap;
  text-align: left;
}

.form-input-2-3 {
  flex: 1;
}

/* 覆盖 Tailwind w-2/3 类，使其在 form-row 中自适应 */
.form-row > .w-2\/3 {
  flex: 1 !important;
  width: auto !important;
}

.form-row .modal-input-select.w-2\/3 {
  flex: 1 !important;
  width: auto !important;
}

/* ColorSelector 已使用 FormRow，不需要额外样式 */

.form-label-block {
  display: block;
}

.form-textarea {
  margin-bottom: 1rem;
}

.form-error {
  font-size: 0.875rem;
  color: var(--color-error-hover);
  margin-bottom: 0.5rem;
  text-align: right;
}

/* Required asterisk */
.required-asterisk {
  color: var(--color-error);
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
}

/* CurrencySelector 样式 - 与普通input保持一致 */
:deep(.currency-selector) {
  margin-bottom: 0 !important;
  display: block !important;
  width: 100% !important;
  padding: 0 !important;
}

:deep(.currency-selector__wrapper) {
  display: block !important;
  width: 100% !important;
  background-color: transparent !important;
  padding: 0 !important;
  margin: 0 !important;
}

:deep(.currency-selector__select) {
  background-color: var(--color-base-200) !important;
  border: 1px solid var(--color-base-300) !important;
  color: var(--color-neutral) !important;
  padding: 0.5rem 0.75rem !important;
  border-radius: 0.75rem !important;
  width: 100% !important;
  font-size: 0.875rem !important;
  box-sizing: border-box !important;
}

:deep(.currency-selector__select option) {
  color: var(--color-neutral) !important;
  background-color: var(--color-base-200) !important;
}

:deep(.currency-selector__select option:disabled) {
  color: var(--color-neutral) !important;
}

:deep(.currency-selector__select:focus) {
  border-color: var(--color-primary) !important;
  box-shadow: 0 0 0 2px rgba(96, 165, 250, 0.2) !important;
}

:deep(.currency-selector__select:disabled) {
  background-color: var(--color-base-300) !important;
  color: var(--color-neutral) !important;
}

/* ReminderSelector 样式统一 */
:deep(.reminder-selector-row) {
  gap: 1rem !important;
}

:deep(.reminder-selector-row .label-text) {
  flex: 0 0 6rem !important;
  width: 6rem !important;
  min-width: 6rem !important;
  max-width: 6rem !important;
}

:deep(.reminder-selector-row .modal-input-select) {
  flex: 1 !important;
  width: 100% !important;
}

/* PrioritySelector 样式统一 */
:deep(.form-group) {
  gap: 1rem !important;
}

:deep(.form-group .form-label) {
  flex: 0 0 6rem !important;
  width: 6rem !important;
  min-width: 6rem !important;
  max-width: 6rem !important;
}

:deep(.form-group .form-field) {
  flex: 1 !important;
  width: 100% !important;
}

/* RepeatPeriodSelector 样式统一 */
:deep(.repeat-period-selector .field-row) {
  gap: 1rem !important;
  margin-bottom: 0.75rem !important;
}

:deep(.repeat-period-selector .label) {
  flex: 0 0 6rem !important;
  width: 6rem !important;
  min-width: 6rem !important;
  max-width: 6rem !important;
}

:deep(.repeat-period-selector .input-field) {
  flex: 1 !important;
  width: 100% !important;
}

/* Advance reminder group */
.advance-reminder-group {
  display: flex;
  flex: 1;
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
  color: var(--color-base-content);
  font-weight: 500;
}

/* Optional text */
.optional-text {
  color: var(--color-neutral);
}

/* Character count */
.character-count {
  font-size: 0.75rem;
  color: var(--color-neutral);
  margin-top: 0.25rem;
  text-align: right;
}

/* Submit button loading state */
.modal-btn-check:disabled {
  background-color: var(--color-base-200);
  color: var(--color-neutral);
  cursor: not-allowed;
}

/* Responsive optimization */
@media (max-width: 640px) {
  .form-row {
    flex-wrap: wrap;
  }

  .form-label {
    margin-bottom: 0.25rem;
    flex-shrink: 0;
  }

  .modal-input-select {
    flex: 1;
    min-width: 0;
  }
}
</style>
