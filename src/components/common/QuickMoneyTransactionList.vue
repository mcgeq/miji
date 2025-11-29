<script setup lang="ts">
// 交易列表组件
import { formatCurrency } from '@/features/money/utils/money';
import { lowercaseFirstLetter } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import type { Transaction } from '@/schema/money';

interface Props {
  transactions: Transaction[];
}

defineProps<Props>();

const { t } = useI18n();
</script>

<template>
  <div class="w-full">
    <div v-if="transactions.length === 0" class="text-center py-8 px-4 text-gray-600 dark:text-gray-400 opacity-50 text-sm">
      暂无交易
    </div>
    <div v-else class="flex flex-col gap-2">
      <div
        v-for="transaction in transactions"
        :key="transaction.serialNum"
        class="flex items-center gap-3 px-3 py-3 md:px-3 md:py-3 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg transition-all cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700 hover:shadow-sm"
      >
        <div
          class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0"
          :class="transaction.transactionType === 'Income' ? 'bg-green-100 text-green-600' : transaction.transactionType === 'Expense' ? 'bg-red-100 text-red-600' : 'bg-blue-100 text-blue-600'"
        >
          <LucidePlusCircle v-if="transaction.transactionType === 'Income'" :size="14" />
          <LucideMinusCircle v-else-if="transaction.transactionType === 'Expense'" :size="14" />
          <LucideArrowRightLeft v-else :size="14" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-semibold text-gray-900 dark:text-white truncate">
            {{ transaction.description }}
          </div>
          <div class="text-xs text-gray-600 dark:text-gray-400 opacity-60 truncate">
            {{ t(`common.categories.${lowercaseFirstLetter(transaction.category)}`) }}<template v-if="transaction.subCategory">
              -{{ t(`common.subCategories.${lowercaseFirstLetter(transaction.subCategory)}`) }}
            </template>
          </div>
        </div>
        <div class="flex flex-col items-end gap-1 flex-shrink-0">
          <div
            class="text-sm font-semibold"
            :class="transaction.transactionType === 'Income' ? 'text-green-600' : 'text-red-600'"
          >
            {{ transaction.transactionType === 'Income' ? '+' : '-' }}{{ formatCurrency(transaction.amount ?? 0) }}
          </div>
          <div class="text-[10px] text-gray-600 dark:text-gray-400 opacity-50 text-right">
            {{ DateUtils.formatDateTime(transaction.date) }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
