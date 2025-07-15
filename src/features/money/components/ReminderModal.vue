<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold">{{ props.reminder ? '编辑提醒' : '添加提醒' }}</h3>
        <button @click="closeModal" class="text-gray-500 hover:text-gray-700">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
      <form @submit.prevent="saveReminder">
        <!-- 提醒标题 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            提醒标题
            <span class="text-red-500 ml-1" aria-label="必填">*</span>
          </label>
          <input
            v-model="form.name"
            type="text"
            required
            class="w-2/3 modal-input-select"
            :class="{ 'border-red-500': validationErrors.name }"
            placeholder="请输入提醒标题"
            @blur="validateName"
          />
        </div>
        <div
          v-if="validationErrors.name"
          class="text-sm text-red-600 dark:text-red-400 mb-2 text-right"
          role="alert"
        >
          {{ validationErrors.name }}
        </div>

        <ReminderSelector
          v-model="form.type"
          label="提醒类型"
          placeholder="请选择类型"
          :required="true"
          :error-message="validationErrors.type"
          :show-grouped="true"
          :show-quick-select="true"
          :show-icons="true"
          :popular-only="false"
          :locale="locale"
          width="2/3"
          quick-select-label="常用类型"
          help-text="选择合适的提醒类型以获得更好的分类和提醒体验"
          @change="handleTypeChange"
          @validate="handleTypeValidation"
        />

        <!-- 金额 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            金额
            <span v-if="isFinanceType" class="text-blue-500 ml-1">*</span>
          </label>
          <div class="w-2/3 flex items-center space-x-2">
            <input
              v-model.number="form.amount"
              type="number"
              step="0.01"
              min="0"
              class="flex-1 modal-input-select"
              :class="{ 'border-red-500': validationErrors.amount }"
              :placeholder="amountPlaceholder"
              :required="isFinanceType"
              @blur="validateAmount"
            />
            <select
              v-model="form.currency"
              class="modal-input-select w-20"
            >
              <option value="CNY">¥</option>
              <option value="USD">$</option>
              <option value="EUR">€</option>
            </select>
          </div>
        </div>
        <div
          v-if="validationErrors.amount"
          class="text-sm text-red-600 dark:text-red-400 mb-2 text-right"
          role="alert"
        >
          {{ validationErrors.amount }}
        </div>

        <!-- 提醒日期 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            提醒日期
            <span class="text-red-500 ml-1" aria-label="必填">*</span>
          </label>
          <input
            v-model="form.remindDate"
            type="date"
            required
            class="w-2/3 modal-input-select"
            :class="{ 'border-red-500': validationErrors.remindDate }"
            :min="today"
            @blur="validateRemindDate"
          />
        </div>
        <div
          v-if="validationErrors.remindDate"
          class="text-sm text-red-600 dark:text-red-400 mb-2 text-right"
          role="alert"
        >
          {{ validationErrors.remindDate }}
        </div>

        <!-- 重复频率  -->
        <RepeatPeriodSelector
          v-model="form.repeatPeriod"
          label="重复频率"
          :error-message="validationErrors.repeatPeriod"
          help-text="设置提醒的重复规则，可以精确控制重复时间"
          @change="handleRepeatPeriodChange"
          @validate="handleRepeatPeriodValidation"
        />

        <!-- 优先级 -->
        <PrioritySelector
          v-model="form.priority"
          label="优先级"
          :error-message="validationErrors.priority"
          :locale="locale"
          :show-icons="true"
          width="2/3"
          help-text="选择合适的优先级来管理提醒的重要程度"
          @change="handlePriorityChange"
          @validate="handlePriorityValidation"
        />

        <!-- 提前提醒 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">提前提醒</label>
          <div class="flex items-center space-x-1 w-2/3">
            <input
              v-model.number="form.advanceValue"
              type="number"
              min="0"
              max="999"
              class="w-1/2 flex-1 modal-input-select"
              placeholder="0"
            />
            <select
              v-model="form.advanceUnit"
              class="modal-input-select"
            >
              <option value="minutes">分钟</option>
              <option value="hours">小时</option>
              <option value="days">天</option>
              <option value="weeks">周</option>
            </select>
          </div>
        </div>

        <!-- 颜色选择 -->
        <div class="mb-2 flex items-center justify-between">
          <label class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">颜色标记</label>
          <ColorSelector
            v-model="form.color"
            :color-names="colorNameMap"
          />
        </div>

        <!-- 启用状态 -->
        <div class="mb-2">
          <label class="flex items-center">
            <input
              v-model="form.enabled"
              type="checkbox"
              class="mr-2"
            />
            <span class="text-sm font-medium text-gray-700 dark:text-gray-300">启用提醒</span>
          </label>
        </div>

        <!-- 描述 -->
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
            描述
            <span class="text-gray-500">(可选)</span>
          </label>
          <textarea
            v-model="form.description"
            rows="3"
            class="w-full modal-input-select"
            :placeholder="descriptionPlaceholder"
            maxlength="200"
          ></textarea>
          <div class="text-xs text-gray-500 dark:text-gray-400 mt-1 text-right">
            {{ form.description?.length || 0 }}/200
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="flex justify-center space-x-3">
          <button
            type="button"
            @click="closeModal"
            class="modal-btn-x"
            :disabled="isSubmitting"
          >
            <X class="wh-5" />
          </button>
          <button
            type="submit"
            class="modal-btn-check"
            :disabled="!isFormValid || isSubmitting"
            :class="{ 'opacity-50 cursor-not-allowed': !isFormValid || isSubmitting }"
          >
            <template v-if="isSubmitting">
              <div class="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
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

<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import { COLORS_MAP, DEFAULT_CURRENCY } from '@/constants/moneyConst';
import ColorSelector from '@/components/common/ColorSelector.vue';
import { uuid } from '@/utils/uuid';
import { getLocalISODateTimeWithOffset } from '@/utils/date';
import { BilReminder } from '@/schema/money';
import {
  CategorySchema,
  PrioritySchema,
  ReminderTypeSchema,
  type Priority,
} from '@/schema/common';
import type { RepeatPeriod } from '@/schema/common';
import ReminderSelector from '@/components/common/ReminderSelector.vue';
import RepeatPeriodSelector from '@/components/common/RepeatPeriodSelector.vue';
import PrioritySelector from '@/components/common/PrioritySelector.vue';

const colorNameMap = ref(COLORS_MAP);

interface Props {
  reminder: BilReminder | null;
}

const props = defineProps<Props>();
const emit = defineEmits(['close', 'save']);

// 响应式状态
const isSubmitting = ref(false);
const locale = ref<'zh-CN' | 'en'>('zh-CN');
const today = ref(new Date().toISOString().split('T')[0]);

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
  type: ReminderTypeSchema.enum.Notification,
  description: '',
  category: CategorySchema.enum.Food,
  amount: 0,
  currency: DEFAULT_CURRENCY[1],
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
  advanceValue: reminder.advanceValue ?? 0, // 使用空值合并运算符确保不为 undefined
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
    return '请输入金额';
  }
  return '0.00（可选）';
});

const descriptionPlaceholder = computed(() => {
  const typeDescriptions = {
    Bill: '如：信用卡账单、水电费等详细信息',
    Income: '如：工资、奖金、投资收益等来源',
    Health: '如：体检项目、医院科室、注意事项等',
    Meeting: '如：会议议题、参与人员、会议地点等',
    Birthday: '如：生日礼物准备、庆祝计划等',
    Travel: '如：行程安排、注意事项、携带物品等',
  };
  return (
    typeDescriptions[form.type as keyof typeof typeDescriptions] ||
    '请输入提醒的详细描述信息'
  );
});

const isFormValid = computed(() => {
  return !!(
    form.name.trim() &&
    form.type &&
    form.remindDate &&
    form.priority &&
    !validationErrors.name &&
    !validationErrors.type &&
    !validationErrors.amount &&
    !validationErrors.remindDate &&
    !validationErrors.repeatPeriod &&
    !validationErrors.priority &&
    (!isFinanceType.value || (form.amount && form.amount > 0))
  );
});

// 验证方法
const validateName = () => {
  if (!form.name.trim()) {
    validationErrors.name = '请输入提醒标题';
  } else if (form.name.trim().length < 2) {
    validationErrors.name = '标题长度至少2个字符';
  } else if (form.name.trim().length > 50) {
    validationErrors.name = '标题长度不能超过50个字符';
  } else {
    validationErrors.name = '';
  }
};

const validateAmount = () => {
  if (isFinanceType.value) {
    if (!form.amount || form.amount <= 0) {
      validationErrors.amount = '财务类提醒必须输入有效金额';
    } else if (form.amount > 999999999) {
      validationErrors.amount = '金额不能超过999,999,999';
    } else {
      validationErrors.amount = '';
    }
  } else {
    validationErrors.amount = '';
  }
};

const validateRemindDate = () => {
  if (!form.remindDate) {
    validationErrors.remindDate = '请选择提醒日期';
  } else {
    const selectedDate = new Date(form.remindDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    if (selectedDate < today) {
      validationErrors.remindDate = '提醒日期不能早于今天';
    } else {
      validationErrors.remindDate = '';
    }
  }
};

// 事件处理
const handleTypeChange = (value: string) => {
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
      form.repeatPeriod = { type: 'Yearly', interval: 1, month: 1, day: 1 }; // 生日和纪念日通常每年重复
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
};

const handleTypeValidation = (isValid: boolean) => {
  if (!isValid) {
    validationErrors.type = '请选择提醒类型';
  } else {
    validationErrors.type = '';
  }
};

const handleRepeatPeriodChange = (value: RepeatPeriod) => {
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
};

const handleRepeatPeriodValidation = (isValid: boolean) => {
  if (!isValid) {
    validationErrors.repeatPeriod = '重复频率配置不完整，请检查必填项';
  } else {
    validationErrors.repeatPeriod = '';
  }
};

const handlePriorityChange = (value: Priority) => {
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
};

const handlePriorityValidation = (isValid: boolean) => {
  if (!isValid) {
    validationErrors.priority = '请选择优先级';
  } else {
    validationErrors.priority = '';
  }
};

const closeModal = () => {
  emit('close');
};

const saveReminder = async () => {
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
      createdAt: props.reminder?.createdAt || getLocalISODateTimeWithOffset(),
      updatedAt: getLocalISODateTimeWithOffset(),
      advanceValue: form.advanceValue || 0, // 确保不为undefined
    };

    emit('save', reminderData);
    closeModal();
  } catch (error) {
    console.error('保存提醒失败:', error);
    // 可以添加错误提示
  } finally {
    isSubmitting.value = false;
  }
};

// 监听器
watch(
  () => props.reminder,
  (newVal) => {
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
  (newVal) => {
    if (newVal === undefined || newVal === null) {
      form.advanceValue = 0;
    }
  },
);
</script>

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
