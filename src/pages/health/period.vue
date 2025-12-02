<script setup lang="ts">
import PeriodManagement from '@/features/health/period/views/PeriodManagement.vue';

definePage({
  name: 'health-period',
  meta: {
    requiresAuth: true,
    layout: 'default',
  },
});
</script>

<template>
  <PeriodManagement />
</template>
