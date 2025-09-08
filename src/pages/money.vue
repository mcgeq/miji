<script setup lang="ts">
import MoneyView from '@/features/money/views/MoneyView.vue';

definePage({
  name: 'money',
  meta: {
    requiresAuth: true,
    layout: 'default',
  },
});
</script>

<template>
  <MoneyView />
</template>
