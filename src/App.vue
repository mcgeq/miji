<script setup lang="ts">
import { storeToRefs } from 'pinia';
import DefaultLayout from './layouts/DefaultLayout.vue';
import EmptyLayout from './layouts/EmptyLayout.vue';
import { checkAndCleanSession } from './services/auth';
import { Lg } from './utils/debugLog';
import { toast } from './utils/toast';
import type { RouteLocationNormalizedLoaded } from 'vue-router';

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
      toast.warning(t('messages.pleaseLogin'));
      await router.replace('/auth/login');
    }
  }
  catch (error) {
    Lg.e('App', error);
    toast.error(t('messages.initFailed'));
  }
  finally {
    isLoading.value = false;
  }
});

function layoutComponent(route: RouteLocationNormalizedLoaded) {
  const layout = route.meta.layout || 'default';
  return layout === 'empty' ? EmptyLayout : DefaultLayout;
}
</script>

<template>
  <div v-if="isLoading" class="loading">
    {{ t('common.loading') }}
  </div>
  <!-- 使用动态过渡名称 -->
  <router-view v-else v-slot="{ Component, route }">
    <transition
      :name="typeof route.meta.transition === 'string' ? route.meta.transition : transitionName"
      mode="out-in"
    >
      <component :is="layoutComponent(route)">
        <component :is="Component" />
      </component>
    </transition>
  </router-view>
</template>

<style>
/* 新增：隐藏滚动条 */
html,
body {
  scrollbar-width: none;
  /* Firefox */
  -ms-overflow-style: none;
  /* IE 和 Edge */
}

html::-webkit-scrollbar,
body::-webkit-scrollbar {
  display: none;
  /* Chrome, Safari, Opera */
}

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
