<template>
  <div class="flex min-h-screen">
    <Sidebar :menu="menuItems" @logout="logout" />

    <div class="flex-1 flex flex-col">
      <main class="flex-1 bg-gray-50">
        <slot />
      </main>
    </div>
  </div>
</template>

<script setup>
import Sidebar from '@/components/common/Sidebar.vue';
import {
  CircleCheckBig,
  FolderDot,
  HandCoins,
  Home,
  Settings,
  Tags,
} from 'lucide-vue-next';
import path from 'path';

const collapsed = ref(false);

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
  console.log('logout: ', router.getRoutes());
  await logoutUser();
  router.replace({ name: 'auth-login' });
};
</script>
