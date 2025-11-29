<script setup lang="ts">
import FamilyLedgerView from '@/features/money/views/FamilyLedgerView.vue';
import { Permission } from '@/types/auth';

definePage({
  name: 'family-ledger',
  meta: {
    requiresAuth: true,
    layout: 'default',
    permissions: [Permission.LEDGER_VIEW],
    title: '家庭账本',
    icon: 'book',
  },
});
</script>

<template>
  <FamilyLedgerView />
</template>
