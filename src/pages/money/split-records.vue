<script setup lang="ts">
import SplitRecordView from '@/features/money/views/SplitRecordView.vue';
import { Permission } from '@/types/auth';

definePage({
  name: 'split-records',
  meta: {
    requiresAuth: true,
    permissions: [Permission.TRANSACTION_VIEW],
    title: '分摆记录查询',
    icon: 'split',
  },
});
</script>

<template>
  <div class="w-full h-full">
    <SplitRecordView />
  </div>
</template>
