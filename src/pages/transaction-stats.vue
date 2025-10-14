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
  <div class="transaction-stats-page">
    <TransactionStatsView />
  </div>
</template>

<style scoped lang="postcss">
.transaction-stats-page {
  min-height: 100vh;
  background: var(--color-base-50);
  width: 100%;
  overflow-x: hidden;
}

/* 移动端优化 */
@media (max-width: 768px) {
  .transaction-stats-page {
    padding: 0;
  }
}

/* 超小屏幕优化 */
@media (max-width: 480px) {
  .transaction-stats-page {
    padding: 0;
  }
}
</style>
