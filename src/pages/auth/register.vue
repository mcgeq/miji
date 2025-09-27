<script setup lang="ts">
import RegisterView from '@/features/auth/register/RegisterView.vue';

definePage({
  name: 'auth-register',
  meta: {
    layout: 'empty',
  },
});
</script>

<template>
  <RegisterView />
</template>
