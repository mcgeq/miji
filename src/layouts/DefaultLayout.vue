<template>
  <div class="flex min-h-screen">
    <Sidebar
      v-if="!isMobile"
      :menu="menuItems"
      @logout="logout"
      class="hidden md:flex fixed left-0 top-0 h-screen z-10"
    />
    <div class="flex-1 flex flex-col md:ml-12">
      <main class="flex-1 bg-gray-50" :class="{ 'pb-16': isMobile }">
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
  Droplet,
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
  {name: 'home', title: 'Home', icon: Home, path: '/'},
  {name: 'todos', title: 'Todo', icon: CircleCheckBig, path: '/todos'},
  {name: 'money', title: 'Money', icon: HandCoins, path: '/money'},
  {
    name: 'health-period',
    title: 'Period',
    icon: Droplet,
    path: '/health/period',
  },
  {name: 'tags', title: 'Tag', icon: Tags, path: '/tags'},
  {name: 'projects', title: 'Project', icon: FolderDot, path: '/projects'},
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
  router.replace({name: 'auth-login'});
};

onMounted(() => {
  window.addEventListener('resize', updateIsMobile);
});

onUnmounted(() => {
  window.removeEventListener('resize', updateIsMobile);
});
</script>
