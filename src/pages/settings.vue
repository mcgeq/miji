<script setup lang="ts">
import SettingsView from '@/features/settings/views/SettingsView.vue';
import { Permission } from '@/types/auth';

definePage({
  name: 'settings',
  meta: {
    requiresAuth: true,
    layout: 'default',
    permissions: [Permission.SETTINGS_VIEW],
    title: '设置',
    icon: 'settings',
  },
});
</script>

<template>
  <SettingsView />
</template>
