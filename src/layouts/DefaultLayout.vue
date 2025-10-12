<script setup lang="ts">
import { CircleCheckBig, Droplet, FolderDot, HandCoins, Home, Settings, Tags } from 'lucide-vue-next';
import MobileBottomNav from '@/components/common/MobileBottomNav.vue';
import Sidebar from '@/components/common/Sidebar.vue';
import { useAuthStore } from '@/stores/auth';
import { toast } from '@/utils/toast';

const isMobile = ref(window.innerWidth < 768);

function updateIsMobile() {
  isMobile.value = window.innerWidth < 768;
}

const menuItems = [
  { name: 'home', title: 'Home', icon: Home, path: '/' },
  { name: 'todos', title: 'Todo', icon: CircleCheckBig, path: '/todos' },
  { name: 'money', title: 'Money', icon: HandCoins, path: '/money' },
  { name: 'health-period', title: 'Period', icon: Droplet, path: '/health/period' },
  { name: 'tags', title: 'Tag', icon: Tags, path: '/tags' },
  { name: 'projects', title: 'Project', icon: FolderDot, path: '/projects' },
  { name: 'settings', title: 'Settings', icon: Settings, path: '/settings' },
];

const router = useRouter();
const authStore = useAuthStore();

async function logout() {
  try {
    // 调用 auth store 的 logout 方法清除用户数据
    await authStore.logout();

    // 显示退出成功提示
    toast.success('退出登录成功');

    // 跳转到登录页
    router.replace({ name: 'auth-login' });
  } catch (error) {
    console.error('Logout failed:', error);
    toast.error('退出登录失败');
  }
}

onMounted(() => {
  window.addEventListener('resize', updateIsMobile);
});

onUnmounted(() => {
  window.removeEventListener('resize', updateIsMobile);
});
</script>

<template>
  <div class="app-container">
    <Sidebar v-if="!isMobile" :menu="menuItems" @logout="logout" />
    <div
      class="main-content"
      :class="{ 'with-bottom-nav': isMobile }"
      :style="{ marginLeft: !isMobile ? '3rem' : '0' }"
    >
      <slot />
    </div>
    <MobileBottomNav v-if="isMobile" :menu="menuItems" />
  </div>
</template>

<style scoped>
.app-container {
  display: flex;
  min-height: 100vh;
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  background-color: var(--color-base-200);
  min-height: 100vh;
  transition: margin-left 0.3s ease;
}

.main-content.with-bottom-nav {
  padding-bottom: 4rem; /* 给底部导航留空间 */
}
</style>
