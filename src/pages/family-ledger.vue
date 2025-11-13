<script setup lang="ts">
import FamilyLedgerView from '@/features/money/views/FamilyLedgerView.vue';

definePage({
  name: 'family-ledger',
  meta: {
    requiresAuth: true,
    layout: 'default',
  },
});
</script>

<template>
  <FamilyLedgerView />
</template>
