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
  <div class="w-full h-full">
    <SplitRecordView />
  </div>
</template>
