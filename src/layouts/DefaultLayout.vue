<script setup>
import {
  CircleCheckBig,
  Droplet,
  FolderDot,
  HandCoins,
  Home,
  Settings,
  Tags,
} from 'lucide-vue-next';
import MobileBottomNav from '@/components/common/MobileBottomNav.vue';
import Sidebar from '@/components/common/Sidebar.vue';

const isMobile = ref(window.innerWidth < 768);

function updateIsMobile() {
  isMobile.value = window.innerWidth < 768;
}

const menuItems = [
  { name: 'home', title: 'Home', icon: Home, path: '/' },
  { name: 'todos', title: 'Todo', icon: CircleCheckBig, path: '/todos' },
  { name: 'money', title: 'Money', icon: HandCoins, path: '/money' },
  {
    name: 'health-period',
    title: 'Period',
    icon: Droplet,
    path: '/health/period',
  },
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
async function logout() {
  await logoutUser();
  router.replace({ name: 'auth-login' });
}

onMounted(() => {
  window.addEventListener('resize', updateIsMobile);
});

onUnmounted(() => {
  window.removeEventListener('resize', updateIsMobile);
});
</script>

<template>
  <div class="min-h-screen flex">
    <Sidebar
      v-if="!isMobile"
      :menu="menuItems"
      class="fixed left-0 top-0 z-10 hidden h-screen md:flex"
      @logout="logout"
    />
    <div class="flex flex-1 flex-col md:ml-12">
      <main class="flex-1 bg-gray-50" :class="{ 'pb-16': isMobile }">
        <slot />
      </main>
      <MobileBottomNav v-if="isMobile" :menu="menuItems" />
    </div>
  </div>
</template>
