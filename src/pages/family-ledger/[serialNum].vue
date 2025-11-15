<script setup lang="ts">
import FamilyLedgerDetailView from '@/features/money/views/FamilyLedgerDetailView.vue';

definePage({
  name: 'family-ledger-detail',
  meta: {
    requiresAuth: true,
    layout: 'default',
  },
});
</script>

<template>
  <FamilyLedgerDetailView />
</template>
