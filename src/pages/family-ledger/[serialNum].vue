<script setup lang="ts">
import FamilyLedgerDetailView from '@/features/money/views/FamilyLedgerDetailView.vue';
import { Permission } from '@/types/auth';

definePage({
  name: 'family-ledger-detail',
  meta: {
    requiresAuth: true,
    layout: 'default',
    permissions: [Permission.LEDGER_VIEW],
    title: '账本详情',
    icon: 'book-open',
  },
});
</script>

<template>
  <FamilyLedgerDetailView />
</template>
