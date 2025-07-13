<template>
  <div class="flex min-h-screen">
    <Sidebar v-if="!isMobile" :menu="menuItems" @logout="logout"  class="hidden md:flex"/>

    <div class="flex-1 flex flex-col">
      <main class="['flex-1 bg-gray-50', isMobile ? 'pb-16' : '']">
        <slot />
      </main>
      <MobileBottomNav v-if="isMobile" :menu="menuItems" />
    </div>
  </div>
</template>

<script setup>
import Sidebar from '@/components/common/Sidebar.vue';
import MobileBottomNav from '@/components/common/MobileBottomNav.vue';

import {
  CircleCheckBig,
  FolderDot,
  HandCoins,
  Home,
  Settings,
  Tags,
} from 'lucide-vue-next';

const collapsed = ref(false);
const isMobile = ref(window.innerWidth < 768);

const updateIsMobile = () => {
  isMobile.value = window.innerWidth < 768;
};

const menuItems = [
  { name: 'home', title: 'Home', icon: Home, path: '/' },
  { name: 'todos', title: 'Todo', icon: CircleCheckBig, path: '/todos' },
  { name: 'money', title: 'Money', icon: HandCoins, path: '/money' },
  { name: 'tags', title: 'Tag', icon: Tags, path: '/tags' },
  { name: 'projects', title: 'Project', icon: FolderDot, path: '/projects' },
  {
    name: 'settings',
    title: 'Settings',
    icon: Settings,
    path: '/settings',
  },
];

const router = useRouter();
const logout = async () => {
  await logoutUser();
  router.replace({ name: 'auth-login' });
};

onMounted(() => {
  window.addEventListener('resize', updateIsMobile);
});

onUnmounted(() => {
  window.removeEventListener('resize', updateIsMobile);
});
</script>
