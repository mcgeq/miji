<template>
  <WelcomeOnboarding @complete="handleComplete" />
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import WelcomeOnboarding from '@/components/onboarding/Welcome.vue';

// 设置页面元信息
definePage({
  meta: {
    title: '欢迎使用',
    requiresAuth: false, // 欢迎页面不需要认证
    layout: 'blank', // 使用空白布局
  },
});

const router = useRouter();

/**
 * 完成引导
 */
function handleComplete() {
  // 跳转到首页
  router.push('/');
}
</script>
