<template>
  <div class="notification-settings-page p-6">
    <div class="max-w-4xl mx-auto">
      <NotificationSettings />
    </div>
  </div>
</template>

<script setup lang="ts">
import NotificationSettings from '@/views/settings/NotificationSettings.vue';

// 设置页面元信息
definePage({
  meta: {
    title: '通知设置',
    requiresAuth: true,
  },
});
</script>

<style scoped>
.notification-settings-page {
  min-height: 100vh;
  background: #f5f5f5;
}
</style>
