<script setup lang="ts">
import { CURRENCY_CNY } from '@/constants/moneyConst';
import { CurrencySchema } from '@/schema/common';
import { MoneyDb } from '@/services/money/money';
import { Lg } from '@/utils/debugLog';
import { uuid } from '@/utils/uuid';
import type { Currency } from '@/schema/common';

// 类型定义
interface PriorityOption {
  value: Currency;
  label: string;
  disabled?: boolean;
}

interface Props {
  modelValue: Currency | null | undefined;
  label?: string;
  required?: boolean;
  disabled?: boolean;
  errorMessage?: string;
  helpText?: string;
  width?: string;
  locale?: 'zh-CN' | 'en';
  customOptions?: PriorityOption[];
}

const props = withDefaults(defineProps<Props>(), {
  label: '货币',
  required: false,
  disabled: false,
  errorMessage: '',
  helpText: '',
  width: '2/3',
  locale: 'zh-CN',
  customOptions: undefined,
});

const emit = defineEmits<{
  (e: 'update:modelValue', value: Currency): void;
  (e: 'change', value: Currency): void;
  (e: 'validate', isValid: boolean): void;
}>();

// 生成唯一ID
const inputId = ref(`currency-selector-${uuid(38)}`);

// 当前值
const currentValue = ref<Currency>(
  props.modelValue && validateValue(props.modelValue) ? props.modelValue : CURRENCY_CNY,
);
const currencies = ref<Currency[]>([CURRENCY_CNY]);

// Fetch currencies asynchronously
async function loadCurrencies() {
  try {
    const fetchedCurrencies = await MoneyDb.listCurrencies();
    if (fetchedCurrencies.length === 0) {
      currencies.value = [CURRENCY_CNY];
      return;
    }
    const hasCNY = fetchedCurrencies.some(c => c.code === CURRENCY_CNY.code);
    currencies.value = hasCNY ? fetchedCurrencies : [CURRENCY_CNY, ...fetchedCurrencies];
  } catch (err: unknown) {
    Lg.e('AccountModal', 'Failed to load currencies:', err);
    currencies.value = [CURRENCY_CNY];
  }
}

// Call loadCurrencies on component setup
loadCurrencies();

// 计算宽度类
const widthClass = computed(() => {
  const widthMap: Record<string, string> = {
    'full': 'w-full',
    '1/2': 'w-1/2',
    '1/3': 'w-1/3',
    '2/3': 'w-2/3',
    '1/4': 'w-1/4',
    '3/4': 'w-3/4',
  };
  return widthMap[props.width] || 'w-2/3';
});

// 是否有错误
const hasError = computed(() => {
  return !!(props.errorMessage && props.errorMessage.trim());
});

// 验证函数
function validateValue(value: Currency): boolean {
  if (props.required && !value) {
    return false;
  }

  try {
    CurrencySchema.parse(value);
    return true;
  } catch {
    return false;
  }
}

// 处理 change 事件
function handleChange(event: Event) {
  const target = event.target as HTMLSelectElement;
  const selectedCode = target.value;

  const selectedCurrency = currencies.value.find(
    curr => curr.code === selectedCode,
  );

  if (selectedCurrency) {
    currentValue.value = selectedCurrency;
    emit('update:modelValue', selectedCurrency);
    emit('change', selectedCurrency);
    emit('validate', true);
  } else {
    emit('validate', false);
  }
}

// 处理 blur 事件
function handleBlur() {
  const isValid = validateValue(currentValue.value);
  emit('validate', isValid);
}

const currencyOptions = computed(() => {
  if (props.customOptions) {
    return props.customOptions.filter(opt =>
      opt.value &&
      typeof opt.value === 'object' &&
      'code' in opt.value,
    );
  }
  return currencies.value.map(currency => ({
    value: currency,
    label: `${currency.code}`,
    disabled: false,
  }));
});

// 公开方法
function focus() {
  const element = document.getElementById(inputId.value);
  if (element) {
    element.focus();
  }
}

function reset() {
  const defaultCurrency = CURRENCY_CNY; // 默认人民币
  currentValue.value = defaultCurrency;
  emit('update:modelValue', defaultCurrency);
  emit('change', defaultCurrency);
  emit('validate', true);
}

function getCurrentCurrencyInfo() {
  return currencyOptions.value.find(
    option => option.value.code === currentValue.value.code,
  );
}

// 监听 modelValue 变化
watch(
  () => props.modelValue,
  newValue => {
    if (newValue === null || !newValue || newValue.code !== currentValue.value?.code) {
      currentValue.value = newValue && validateValue(newValue) ? newValue : CURRENCY_CNY;
    }
  },
  { immediate: true },
);

// 监听 currentValue 变化
watch(currentValue, newValue => {
  if (newValue && newValue.code !== props.modelValue?.code) {
    emit('update:modelValue', newValue);
  }
});

defineExpose({
  focus,
  reset,
  getCurrentCurrencyInfo,
  validate: () => {
    const val = currentValue.value;
    return validateValue(val);
  },
});
</script>

<template>
  <div id="currency-selector" class="mb-2 flex items-center justify-between">
    <div class="flex flex-col" :class="widthClass">
      <select
        :id="inputId"
        v-model="currentValue.code"
        class="modal-input-select" :class="[
          {
            'border-red-500': hasError,
            'border-gray-300 dark:border-gray-600': !hasError,
          },
        ]"
        :required="required"
        :disabled="disabled"
        @blur="handleBlur"
        @change="handleChange"
      >
        <option
          v-for="option in currencyOptions"
          :key="option.value.code"
          :value="option.value.code"
          :disabled="option.disabled"
        >
          {{ option.label }}
        </option>
      </select>
      <div
        v-if="hasError && errorMessage"
        class="text-sm text-red-600 mt-1 dark:text-red-400"
        role="alert"
      >
        {{ errorMessage }}
      </div>
      <div
        v-if="helpText && !hasError"
        class="text-xs text-gray-500 mt-2 flex justify-end dark:text-gray-400"
      >
        {{ helpText }}
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 基础样式 */
.modal-input-select {
  @apply px-3 py-2 border rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-colors;
}

/* 错误状态 */
.border-red-500:focus {
  @apply ring-2 ring-red-400 ring-opacity-50 border-red-500;
}

/* 禁用状态 */
.modal-input-select:disabled {
  @apply bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 cursor-not-allowed;
}

/* 选项样式 */
.modal-input-select option {
  @apply py-2 px-3;
}

.modal-input-select option:disabled {
  @apply text-gray-400 dark:text-gray-500;
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

/* 深色模式优化 */
@media (prefers-color-scheme: dark) {
  .modal-input-select {
    @apply border-gray-600;
  }

  .modal-input-select:focus {
    @apply ring-blue-400;
  }
}
</style>
