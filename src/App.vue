<script setup lang="ts">
import { storeToRefs } from 'pinia';
import CloseDialog from './components/common/CloseDialog.vue';
import DefaultLayout from './layouts/DefaultLayout.vue';
import EmptyLayout from './layouts/EmptyLayout.vue';
import { checkAndCleanSession } from './services/auth';
import { PlatformService } from './services/platform-service';
import { useAuthStore } from './stores/auth';
import { Lg } from './utils/debugLog';
import { toast } from './utils/toast';
import type { RouteLocationNormalizedLoaded } from 'vue-router';

const isLoading = ref(true);
const router = useRouter();
const { t } = useI18n();
const transitionStore = useTransitionsStore();
const { name: transitionName } = storeToRefs(transitionStore);
const authStore = useAuthStore();

onMounted(async () => {
  try {
    // 等待 store 数据从持久化存储加载完成
    // storeStart() 在 main.ts 中已经调用了 $tauri.start()
    // 但我们需要等待数据实际加载完成
    await nextTick();

    // 平台特定延迟
    await PlatformService.delay(50, 150);

    Lg.i('App', 'Auth check - token:', authStore.token ? 'exists' : 'null', 'rememberMe:', authStore.rememberMe);

    // 仅在桌面端清理 session（移动设备保持登录状态）
    if (PlatformService.isDesktop()) {
      await checkAndCleanSession();
    }

    // 认证检查（移动端使用超时处理）
    let auth = false;
    if (PlatformService.isMobile()) {
      try {
        auth = await PlatformService.executeWithTimeout(
          authStore.checkAuthStatus(),
          2000, // 移动端2秒超时
          5000, // 桌面端5秒超时
        );
      } catch (error) {
        Lg.w('App', 'Auth check timed out, assuming not authenticated:', error);
        auth = false;
      }
    } else {
      auth = await authStore.checkAuthStatus();
    }

    if (!auth && router.currentRoute.value.path !== '/auth/login') {
      toast.warning(t('messages.pleaseLogin'));
      await router.replace('/auth/login');
    }
  } catch (error) {
    Lg.e('App', error);
    // 移动设备不显示错误提示，避免阻塞启动
    if (PlatformService.isDesktop()) {
      toast.error(t('messages.initFailed'));
    }
  } finally {
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

  <!-- 关闭对话框 -->
  <CloseDialog />
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
  color: var(--color-base-content);
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
