<script setup lang="ts">
  import type { SelectOption } from '@/components/ui/Select.vue';
  import Select from '@/components/ui/Select.vue';
  import type { Account } from '@/schema/money';
  import { useAccountStore } from '@/stores/money';

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
  const accountStore = useAccountStore();
  const fetchedAccounts = ref<Account[]>(props.accounts);

  // 挂载时加载账户
  onMounted(async () => {
    try {
      // 如果 accountStore 还没有账户数据，就加载
      if (accountStore.accounts.length === 0) {
        await accountStore.fetchAccounts();
      }
      fetchedAccounts.value = accountStore.accounts;
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

  // 转换为 Select 组件的选项格式
  const accountOptions = computed<SelectOption[]>(() =>
    availableAccounts.value.map(account => ({
      value: account.serialNum,
      label: `${account.name} (${account.currency.symbol}${accountStore.isAccountAmountHidden(account.serialNum) ? '***' : account.balance})`,
    })),
  );

  // Select 尺寸映射
  const selectSize = computed(() => {
    const sizeMap = {
      sm: 'sm' as const,
      base: 'md' as const,
      lg: 'lg' as const,
    };
    return sizeMap[props.size];
  });

  // 宽度类
  const widthClass = computed(() => {
    const widthMap = {
      full: 'w-full',
      auto: 'w-auto',
      '2/3': 'w-2/3',
      '1/2': 'w-1/2',
      '1/3': 'w-1/3',
    };
    return widthMap[props.width];
  });

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
  <div :class="widthClass">
    <div
      class="flex gap-2 items-center max-sm:flex-col max-sm:items-stretch"
      :class="[
        showQuickSelect ? 'justify-between' : 'justify-end',
      ]"
    >
      <!-- 快捷选择 -->
      <div
        v-if="showQuickSelect && quickSelectAccounts.length"
        class="flex gap-2 items-center max-sm:justify-center"
        role="group"
        :aria-label="quickSelectLabel"
      >
        <button
          v-for="account in quickSelectAccounts"
          :key="account.serialNum"
          type="button"
          class="py-1 px-3 border rounded-md text-sm cursor-pointer transition-all duration-200 bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 border-gray-300 dark:border-gray-600"
          :class="[
            selectedAccount === account.serialNum
              ? 'bg-blue-500 text-white border-blue-500'
              : 'hover:bg-gray-100 dark:hover:bg-gray-700',
            disabled && 'bg-gray-200 dark:bg-gray-700 text-gray-500 dark:text-gray-400 cursor-not-allowed',
          ]"
          :disabled="disabled"
          :title="account.name"
          @click="selectQuickAccount(account.serialNum)"
        >
          <span v-if="showIcons && account.color" class="mr-2" :style="{ color: account.color }"
            >●</span
          >
          {{ account.name }}
        </button>
      </div>

      <!-- 下拉选择 -->
      <div class="max-sm:w-full" :class="[widthClass === 'w-full' ? 'w-full' : 'w-2/3']">
        <Select
          :model-value="selectedAccount || ''"
          :options="accountOptions"
          :placeholder="placeholder"
          :size="selectSize"
          :disabled="disabled"
          :error="errorMessage"
          full-width
          @update:model-value="(val) => selectedAccount = val as string"
        />
      </div>
    </div>

    <!-- 帮助文本 -->
    <div v-if="helpText" class="mt-2 text-xs text-gray-500 dark:text-gray-400">{{ helpText }}</div>
  </div>
</template>
