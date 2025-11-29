<script setup lang="ts">
// 这个页面直接导入并使用TransactionStatsView组件
import TransactionStatsView from '@/features/money/views/TransactionStatsView.vue';

definePage({
  name: 'transaction-stats',
  meta: {
    requiresAuth: true,
    layout: 'default',
  },
});
</script>

<template>
  <div class="min-h-screen w-full overflow-x-hidden bg-gray-50 dark:bg-gray-900">
    <TransactionStatsView />
  </div>
</template>
