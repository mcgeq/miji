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
    'half': 'w-half',
    'third': 'w-third',
    'two-thirds': 'w-two-thirds',
    'quarter': 'w-quarter',
    'three-quarters': 'w-three-quarters',
  };
  return widthMap[props.width] || 'w-two-thirds';
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
  <div id="currency-selector" class="currency-selector">
    <div class="currency-selector__wrapper" :class="widthClass">
      <select
        :id="inputId"
        v-model="currentValue.code"
        class="currency-selector__select"
        :class="{ 'has-error': hasError }"
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

      <div v-if="hasError && errorMessage" class="currency-selector__error" role="alert">
        {{ errorMessage }}
      </div>

      <div v-if="helpText && !hasError" class="currency-selector__help">
        {{ helpText }}
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.currency-selector {
  margin-bottom: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.currency-selector__wrapper {
  display: flex;
  flex-direction: column;
}

.w-full {
  width: 100%;
}
.w-half {
  width: 50%;
}
.w-third {
  width: 33.3333%;
}
.w-two-thirds {
  width: 66.6666%;
}
.w-quarter {
  width: 25%;
}
.w-three-quarters {
  width: 75%;
}

.currency-selector__select {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-neutral);
  border-radius: 0.375rem;
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  transition: border-color 0.2s, box-shadow 0.2s;
}

.currency-selector__select:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-soft);
}

.currency-selector__select:disabled {
  background-color: var(--color-base-200);
  color: var(--color-neutral-content);
  cursor: not-allowed;
}

.currency-selector__select.has-error {
  border-color: var(--color-error);
}

.currency-selector__select.has-error:focus {
  box-shadow: 0 0 0 2px var(--color-error);
}

.currency-selector__select option {
  padding: 0.5rem 0.75rem;
}

.currency-selector__select option:disabled {
  color: var(--color-neutral-content);
}

.currency-selector__error {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: var(--color-error);
}

.currency-selector__help {
  margin-top: 0.5rem;
  font-size: 0.75rem;
  text-align: right;
  color: var(--color-neutral-content);
}

@media (max-width: 640px) {
  .currency-selector {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
