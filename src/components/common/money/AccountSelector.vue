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
    fetchedAccounts.value = moneyStore.accounts;
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
    class="account-selector"
    :class="[
      width === 'full' ? 'w-full' : '',
      width === 'auto' ? 'w-auto' : '',
      width === '2/3' ? 'w-two-thirds' : '',
      width === '1/2' ? 'w-half' : '',
      width === '1/3' ? 'w-third' : '',
    ]"
  >
    <div
      class="account-selector__inner"
      :class="showQuickSelect ? 'justify-between' : 'justify-end'"
    >
      <!-- 快捷选择 -->
      <div
        v-if="showQuickSelect && quickSelectAccounts.length"
        class="quick-select-group"
        role="group"
        :aria-label="quickSelectLabel"
      >
        <button
          v-for="account in quickSelectAccounts"
          :key="account.serialNum"
          type="button"
          class="quick-select-btn"
          :class="{ 'quick-select-btn--active': selectedAccount === account.serialNum }"
          :disabled="disabled"
          :title="account.name"
          @click="selectQuickAccount(account.serialNum)"
        >
          <span
            v-if="showIcons && account.color"
            class="quick-select-icon"
            :style="{ color: account.color }"
          >●</span>
          {{ account.name }}
        </button>
      </div>

      <!-- 下拉选择 -->
      <select
        :id="inputId"
        v-model="selectedAccount"
        :disabled="disabled"
        class="account-selector__select"
        :class="[
          size === 'sm' ? 'account-selector__select--sm' : '',
          size === 'base' ? 'account-selector__select--base' : '',
          size === 'lg' ? 'account-selector__select--lg' : '',
          errorMessage ? 'has-error' : '',
        ]"
        :aria-describedby="errorMessage ? `${inputId}-error` : undefined"
      >
        <option value="" disabled>
          {{ placeholder }}
        </option>
        <option
          v-for="account in availableAccounts"
          :key="account.serialNum"
          :value="account.serialNum"
        >
          {{ account.name }} ({{ account.currency.symbol }}{{ account.balance }})
        </option>
      </select>
    </div>

    <!-- 错误提示 -->
    <div
      v-if="errorMessage"
      :id="`${inputId}-error`"
      class="account-selector__error"
      role="alert"
      aria-live="polite"
    >
      {{ errorMessage }}
    </div>

    <!-- 帮助文本 -->
    <div v-if="helpText" class="account-selector__help">
      {{ helpText }}
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 主容器 */
.account-selector {
  display: block;
}
.account-selector__inner {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}
.account-selector__inner.justify-between {
  justify-content: space-between;
}
.account-selector__inner.justify-end {
  justify-content: flex-end;
}

/* 快捷选择 */
.quick-select-group {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}
.quick-select-btn {
  padding: 0.25rem 0.75rem;
  border: 1px solid var(--color-neutral);
  border-radius: 0.375rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
  font-size: 0.875rem;
  cursor: pointer;
  transition: background 0.2s, border-color 0.2s;
}
.quick-select-btn:hover:not(:disabled) {
  background: var(--color-base-200);
}
.quick-select-btn:disabled {
  background: var(--color-base-200);
  color: var(--color-neutral-content);
  cursor: not-allowed;
}
.quick-select-btn--active {
  background: var(--color-primary);
  color: var(--color-primary-content);
  border-color: var(--color-primary);
}
.quick-select-icon {
  margin-right: 0.5rem;
}

/* 下拉选择 */
.account-selector__select {
  display: block;
  width: 66.6666%; /* 默认 w-2/3 */
  border: 1px solid var(--color-neutral);
  border-radius: 0.375rem;
  background: var(--color-base-100);
  color: var(--color-base-content);
  transition: border-color 0.2s, box-shadow 0.2s;
}
.account-selector__select:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-soft);
}
.account-selector__select:disabled {
  background: var(--color-base-200);
  color: var(--color-neutral-content);
  cursor: not-allowed;
}
.account-selector__select.has-error {
  border-color: var(--color-error);
}
.account-selector__select.has-error:focus {
  box-shadow: 0 0 0 2px var(--color-error);
}

/* 下拉大小 */
.account-selector__select--sm {
  font-size: 0.875rem;
  padding: 0.25rem 0.5rem;
}
.account-selector__select--base {
  font-size: 1rem;
  padding: 0.5rem 0.75rem;
}
.account-selector__select--lg {
  font-size: 1.125rem;
  padding: 0.75rem 1rem;
}

/* 错误提示 */
.account-selector__error {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: var(--color-error);
}

/* 帮助文本 */
.account-selector__help {
  margin-top: 0.5rem;
  font-size: 0.75rem;
  color: var(--color-neutral-content);
}
</style>
