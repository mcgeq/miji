<script setup lang="ts">
  import Select from '@/components/ui/Select.vue';
  import type { SelectOption } from '@/components/ui/types';
  import { CURRENCY_CNY } from '@/constants/moneyConst';
  import type { Currency } from '@/schema/common';
  import { CurrencySchema } from '@/schema/common';
  import { MoneyDb } from '@/services/money/money';
  import { Lg } from '@/utils/debugLog';

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
      full: 'w-full',
      half: 'w-1/2',
      third: 'w-1/3',
      'two-thirds': 'w-2/3',
      '2/3': 'w-2/3',
      quarter: 'w-1/4',
      'three-quarters': 'w-3/4',
    };
    return widthMap[props.width] || 'w-2/3';
  });

  // 是否有错误
  const hasError = computed(() => {
    return !!props.errorMessage?.trim();
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
  function handleChange(value: string | number | (string | number)[]) {
    const selectedCode = value as string;

    const selectedCurrency = currencies.value.find(curr => curr.code === selectedCode);

    if (selectedCurrency) {
      currentValue.value = selectedCurrency;
      emit('update:modelValue', selectedCurrency);
      emit('change', selectedCurrency);
      emit('validate', true);
    } else {
      emit('validate', false);
    }
  }

  // 转换为 SelectOption 格式
  const selectOptions = computed<SelectOption[]>(() => {
    if (props.customOptions) {
      return props.customOptions
        .filter(opt => opt.value && typeof opt.value === 'object' && 'code' in opt.value)
        .map(opt => ({
          value: opt.value.code,
          label: `${opt.value.code} - ${opt.value.symbol}`,
          disabled: opt.disabled,
        }));
    }
    return currencies.value.map(currency => ({
      value: currency.code,
      label: `${currency.code} - ${currency.symbol}`,
    }));
  });

  const currencyOptions = computed(() => {
    if (props.customOptions) {
      return props.customOptions.filter(
        opt => opt.value && typeof opt.value === 'object' && 'code' in opt.value,
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
    // Select 组件没有直接的 focus 方法，可以考虑添加 ref
  }

  function reset() {
    const defaultCurrency = CURRENCY_CNY; // 默认人民币
    currentValue.value = defaultCurrency;
    emit('update:modelValue', defaultCurrency);
    emit('change', defaultCurrency);
    emit('validate', true);
  }

  function getCurrentCurrencyInfo() {
    return currencyOptions.value.find(option => option.value.code === currentValue.value.code);
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
  <div class="mb-2 flex items-center justify-between max-sm:flex-col max-sm:items-stretch">
    <div class="flex flex-col" :class="[widthClass]">
      <Select
        :model-value="currentValue.code"
        :options="selectOptions"
        :placeholder="label"
        size="md"
        :required="required"
        :disabled="disabled"
        :error="hasError ? errorMessage : undefined"
        full-width
        @update:model-value="handleChange"
      />

      <div
        v-if="helpText && !hasError"
        class="mt-2 text-xs text-right text-gray-500 dark:text-gray-400"
      >
        {{ helpText }}
      </div>
    </div>
  </div>
</template>
