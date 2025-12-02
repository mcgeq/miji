<script setup lang="ts">
import DebtRelationView from '@/features/money/views/DebtRelationView.vue';
import { Permission } from '@/types/auth';

definePage({
  name: 'money-debt-relations',
  meta: {
    requiresAuth: true,
    layout: 'default',
    permissions: [Permission.TRANSACTION_VIEW],
    title: '债务关系',
    icon: 'git-compare',
  },
});
</script>

<template>
  <DebtRelationView />
</template>
