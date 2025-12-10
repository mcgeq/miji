<script setup lang="ts">
  import {
    BarChart3,
    BookOpen,
    CircleCheckBig,
    Droplet,
    HandCoins,
    Home,
    Settings,
    Users,
  } from 'lucide-vue-next';
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
    {
      name: 'money',
      title: 'Money',
      icon: HandCoins,
      path: '/money',
      hasSubmenu: true,
      submenu: [
        { name: 'money-overview', title: '账本概览', path: '/money', icon: HandCoins },
        { name: 'family-ledger', title: '家庭记账', path: '/family-ledger', icon: Users },
      ],
    },
    { name: 'transaction-stats', title: 'Statistics', icon: BarChart3, path: '/transaction-stats' },
    { name: 'health-period', title: 'Period', icon: Droplet, path: '/health/period' },
    { name: 'dictionaries', title: 'Dictionaries', icon: BookOpen, path: '/dictionaries' },
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
  <div class="flex min-h-screen">
    <Sidebar v-if="!isMobile" :menu="menuItems" @logout="logout" />
    <div
      class="flex-1 flex flex-col bg-gray-100 dark:bg-gray-900 transition-all duration-300"
      :class="[
        isMobile ? 'min-h-[calc(100vh-3rem)] pb-16 overflow-y-auto' : 'min-h-screen ml-12',
      ]"
    >
      <slot />
    </div>
    <MobileBottomNav v-if="isMobile" :menu="menuItems" />
  </div>
</template>
