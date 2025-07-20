<script setup lang="ts">
import SettingsView from '@/features/settings/views/SettingsView.vue';

definePage({
  name: 'settings',
  meta: {
    requiresAuth: true,
    layout: 'default',
  },
});
</script>

<template>
  <SettingsView />
</template>
