<script setup lang="ts">
import MoneyView from '@/features/money/views/MoneyView.vue';
import { Permission } from '@/types/auth';

definePage({
  name: 'money',
  meta: {
    requiresAuth: true,
    layout: 'default',
    permissions: [Permission.TRANSACTION_VIEW],
    title: '财务管理',
    icon: 'wallet',
  },
});
</script>

<template>
  <MoneyView />
</template>
