<script setup lang="ts">
// 账户列表组件
import { formatCurrency } from '@/features/money/utils/money';
import type { Account } from '@/schema/money';

interface Props {
  accounts: Account[];
  amountHidden?: boolean;
}

withDefaults(defineProps<Props>(), {
  amountHidden: false,
});

const { t } = useI18n();
</script>

<template>
  <div class="w-full">
    <div v-if="accounts.length === 0" class="text-center py-8 px-4 text-gray-600 dark:text-gray-400 opacity-50 text-sm">
      暂无账户
    </div>
    <div v-else class="flex flex-col gap-2">
      <div
        v-for="account in accounts"
        :key="account.serialNum"
        class="flex items-center gap-3 px-3 py-3 md:px-3 md:py-3 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg transition-all cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700 hover:shadow-sm"
      >
        <div
          class="w-8 h-8 rounded-lg flex items-center justify-center text-white flex-shrink-0 overflow-hidden"
          :style="account.color ? { backgroundColor: account.color } : { backgroundColor: '#6b7280' }"
        >
          <LucideCreditCard :size="14" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-semibold text-gray-900 dark:text-white truncate">
            {{ account.name }}
          </div>
          <div class="text-xs text-gray-600 dark:text-gray-400 opacity-60 truncate">
            {{ t(`financial.accountTypes.${account.type.toLocaleLowerCase()}`) }}
          </div>
        </div>
        <div class="text-sm font-semibold text-gray-900 dark:text-white">
          {{ amountHidden ? '***' : formatCurrency(account.balance ?? 0) }}
        </div>
      </div>
    </div>
  </div>
</template>
