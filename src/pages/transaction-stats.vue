<script setup lang="ts">
  // 这个页面直接导入并使用TransactionStatsView组件
  import TransactionStatsView from '@/features/money/views/TransactionStatsView.vue';
  import { Permission } from '@/types/auth';

  definePage({
    name: 'transaction-stats',
    meta: {
      requiresAuth: true,
      layout: 'default',
      permissions: [Permission.TRANSACTION_VIEW, Permission.STATS_VIEW],
      title: '交易统计',
      icon: 'trending-up',
    },
  });
</script>

<template>
  <div class="min-h-screen w-full overflow-x-hidden bg-gray-50 dark:bg-gray-900">
    <TransactionStatsView />
  </div>
</template>
