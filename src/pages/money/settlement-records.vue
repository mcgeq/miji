<script setup lang="ts">
import SettlementRecordList from '@/features/money/views/SettlementRecordList.vue';
import { Permission } from '@/types/auth';

definePage({
  name: 'money-settlement-records',
  meta: {
    requiresAuth: true,
    layout: 'default',
    permissions: [Permission.TRANSACTION_VIEW],
    title: '结算记录',
    icon: 'receipt',
  },
});
</script>

<template>
  <SettlementRecordList />
</template>
