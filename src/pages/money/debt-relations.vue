<script setup lang="ts">
import DebtRelationView from '@/features/money/views/DebtRelationView.vue';

definePage({
  name: 'money-debt-relations',
  meta: {
    requiresAuth: true,
    layout: 'default',
  },
});
</script>

<template>
  <DebtRelationView />
</template>
