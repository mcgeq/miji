<template>
  <LoginView />
</template>

<script setup lang="ts">
import LoginView from '@/features/auth/login/LoginView.vue';
definePage({
  name: 'auth-login',
  meta: {
    layout: 'empty',
  },
});
</script>
