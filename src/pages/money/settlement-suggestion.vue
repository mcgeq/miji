<script setup lang="ts">
import SettlementSuggestionView from '@/features/money/views/SettlementSuggestionView.vue';
import { Permission } from '@/types/auth';

definePage({
  name: 'money-settlement-suggestion',
  meta: {
    requiresAuth: true,
    layout: 'default',
    permissions: [Permission.TRANSACTION_VIEW],
    title: '结算建议',
    icon: 'lightbulb',
  },
});
</script>

<template>
  <SettlementSuggestionView />
</template>
