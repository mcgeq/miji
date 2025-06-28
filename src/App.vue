<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { isAuthenticated } from '@/stores/auth';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { toast } from '@/utils/toast';

const isLoading = ref(true);
const router = useRouter();
const { t } = useI18n();

onMounted(async () => {
  try {
    const auth = await isAuthenticated();

    if (!auth) {
      toast.warning(t('errors.pleaseLogin'));
      await router.replace('/auth/login');
    } else {
      // 登录则默认跳转到受保护页面，比如 /todos
      if (router.currentRoute.value.path === '/') {
        await router.replace('/todos');
      }
    }
  } catch (error) {
    toast.error(t('errors.initFailed'));
    console.error('初始化登录状态失败', error);
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
  min-height: 100%;
  height: 100vh;
  overflow: hidden;
}


html, body, #app {
  height: 100%;
  margin: 0;
  padding: 0;
  overflow: hidden;
}
</style>
