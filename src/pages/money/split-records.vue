<script setup lang="ts">
import SplitRecordView from '@/features/money/views/SplitRecordView.vue';

definePage({
  name: 'split-records',
  meta: {
    requiresAuth: true,
    title: '分摊记录查询',
  },
});
</script>

<template>
  <div class="split-records-page">
    <SplitRecordView />
  </div>
</template>

<style scoped>
.split-records-page {
  width: 100%;
  height: 100%;
}
</style>
