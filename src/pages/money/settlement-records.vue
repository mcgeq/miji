<script setup lang="ts">
import SettlementRecordList from '@/features/money/views/SettlementRecordList.vue';

definePage({
  name: 'money-settlement-records',
  meta: {
    requiresAuth: true,
    layout: 'default',
  },
});
</script>

<template>
  <SettlementRecordList />
</template>
