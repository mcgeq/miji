<script setup lang="ts">
import SettlementSuggestionView from '@/features/money/views/SettlementSuggestionView.vue';

definePage({
  name: 'money-settlement-suggestion',
  meta: {
    requiresAuth: true,
    layout: 'default',
  },
});
</script>

<template>
  <SettlementSuggestionView />
</template>
