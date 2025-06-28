<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { toast } from '@/utils/toast';
import { isAuthenticated } from '@/stores/auth';
import { checkAndCleanSession } from './services/auth';

const isLoading = ref(true);
const router = useRouter();
const { t } = useI18n();

onMounted(async () => {
  try {
    await checkAndCleanSession(); // 可选
    const auth = await isAuthenticated();

    if (!auth && router.currentRoute.value.path !== '/auth/login') {
      toast.warning(t('errors.pleaseLogin'));
      await router.replace('/auth/login');
    }
  } catch (error) {
    toast.error(t('errors.initFailed'));
    console.error('初始化登录状态失败:', error);
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div v-if="isLoading" class="loading">{{ t('loading') }}</div>
  <router-view v-else />
</template>

<style>
.loading {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  font-size: 1.2rem;
  color: #333;
}
</style>
