<script setup lang="ts">
import { useMoneyStore } from '@/stores/moneyStore';
import type { Account } from '@/schema/money';

// Props（不包含 modelValue）
export interface AccountSelectorProps {
  label?: string;
  placeholder?: string;
  helpText?: string;
  required?: boolean;
  disabled?: boolean;
  locale?: 'zh-CN' | 'en';
  accounts?: Account[];
  errorMessage?: string;
  size?: 'sm' | 'base' | 'lg';
  width?: 'full' | 'auto' | '2/3' | '1/2' | '1/3';
  showIcons?: boolean;
  showQuickSelect?: boolean;
  quickSelectLabel?: string;
  customQuickAccounts?: Account[];
}

// 默认值
const props = withDefaults(defineProps<AccountSelectorProps>(), {
  label: '账户',
  placeholder: '请选择账户',
  helpText: '',
  required: false,
  disabled: false,
  locale: 'zh-CN',
  accounts: () => [],
  errorMessage: '',
  size: 'base',
  width: 'full',
  showIcons: true,
  showQuickSelect: true,
  quickSelectLabel: '常用账户',
  customQuickAccounts: () => [],
});

// v-model 绑定
const selectedAccount = defineModel<string | null>('modelValue', { default: null });

// store
const moneyStore = useMoneyStore();
const fetchedAccounts = ref<Account[]>(props.accounts);
const inputId = useId();

// 挂载时加载账户
onMounted(async () => {
  try {
    fetchedAccounts.value = await moneyStore.getAllAccounts();
  } catch (error) {
    console.error('获取账户失败:', error);
  }
});

// 可用账户
const availableAccounts = computed(() =>
  props.accounts.length > 0 ? props.accounts : fetchedAccounts.value,
);

// 快捷账户
const quickSelectAccounts = computed<Account[]>(() =>
  props.customQuickAccounts.length > 0
    ? props.customQuickAccounts.slice(0, 1)
    : fetchedAccounts.value.slice(0, 1),
);

// 验证
const isValid = computed(() => {
  if (!props.required) return true;
  return !!selectedAccount.value;
});

// 快捷选择
function selectQuickAccount(serialNum: string) {
  if (props.disabled) return;
  selectedAccount.value = serialNum;
}

// 暴露方法
defineExpose({
  validate: () => isValid.value,
  reset: () => {
    selectedAccount.value = null;
  },
});
</script>

<template>
  <div
    class="account-selector" :class="{
      'w-full': width === 'full',
      'w-auto': width === 'auto',
      'w-2/3': width === '2/3',
      'w-1/2': width === '1/2',
      'w-1/3': width === '1/3',
    }"
  >
    <div class="flex gap-2 items-center" :class="showQuickSelect ? 'justify-between' : 'justify-end'">
      <!-- 快捷选择 -->
      <div v-if="showQuickSelect && quickSelectAccounts.length" class="flex gap-2 items-center" role="group" :aria-label="quickSelectLabel">
        <button
          v-for="account in quickSelectAccounts"
          :key="account.serialNum"
          type="button"
          class="quick-select-btn"
          :class="{ 'quick-select-btn-active': selectedAccount === account.serialNum }"
          :disabled="disabled"
          :title="account.name"
          @click="selectQuickAccount(account.serialNum)"
        >
          <span v-if="showIcons && account.color" class="mr-2" :style="{ color: account.color }">●</span>
          {{ account.name }}
        </button>
      </div>

      <!-- 下拉选择 -->
      <select
        :id="inputId"
        v-model="selectedAccount"
        :disabled="disabled"
        class="text-gray-900 border border-gray-300 rounded-md bg-white w-2/3 block dark:text-gray-100 dark:border-gray-600 focus:border-blue-500 dark:bg-gray-800 focus:ring-2 focus:ring-blue-500"
        :class="{
          'text-sm py-1': size === 'sm',
          'text-base py-2': size === 'base',
          'text-lg py-3': size === 'lg',
          'border-red-500': errorMessage,
        }"
        :aria-describedby="errorMessage ? `${inputId}-error` : undefined"
      >
        <option value="" disabled>
          {{ placeholder }}
        </option>
        <option v-for="account in availableAccounts" :key="account.serialNum" :value="account.serialNum">
          {{ account.name }} ({{ account.currency.symbol }}{{ account.balance }})
        </option>
      </select>
    </div>

    <!-- 错误提示 -->
    <div v-if="errorMessage" :id="`${inputId}-error`" class="text-sm text-red-600 mt-1 dark:text-red-400" role="alert" aria-live="polite">
      {{ errorMessage }}
    </div>

    <!-- 帮助文本 -->
    <div v-if="helpText" class="text-xs text-gray-500 mt-2 dark:text-gray-400">
      {{ helpText }}
    </div>
  </div>
</template>
