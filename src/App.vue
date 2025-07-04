<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { toast } from '@/utils/toast';
import { checkAndCleanSession } from './services/auth';
import { useTransitionsStore } from './stores/transition';
import { storeToRefs } from 'pinia';

const isLoading = ref(true);
const router = useRouter();
const { t } = useI18n();
const transitionStore = useTransitionsStore();
const { name: transitionName } = storeToRefs(transitionStore);

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
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div v-if="isLoading" class="loading">{{ t('loading') }}</div>
  <!-- 使用动态过渡名称 -->
  <router-view v-else v-slot="{ Component, route }">
    <transition :name="typeof route.meta.transition === 'string' ? route.meta.transition : transitionName"
      mode="out-in">
      <component :is="Component" />
    </transition>
  </router-view>
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

/* 可以在 App.vue 或全局样式中定义 */
.slide-left-enter-active,
.slide-left-leave-active,
.slide-right-enter-active,
.slide-right-leave-active {
  transition: transform 0.3s ease, opacity 0.3s ease;
  position: absolute;
  width: 100%;
}

.slide-left-enter-from,
.slide-right-leave-to {
  transform: translateX(100%);
  opacity: 0;
}

.slide-left-leave-to,
.slide-right-enter-from {
  transform: translateX(-100%);
  opacity: 0;
}

.slide-right-enter-from,
.slide-left-leave-to {
  transform: translateX(-100%);
  opacity: 0;
}

.slide-right-leave-to,
.slide-left-enter-from {
  transform: translateX(100%);
  opacity: 0;
}
</style>
