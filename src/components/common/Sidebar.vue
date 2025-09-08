<script setup lang="ts">
import { LogOut } from 'lucide-vue-next';

const { menu } = defineProps<{
  menu: Array<{
    name: string;
    title: string;
    icon: any;
    path: string;
  }>;
}>();
const emit = defineEmits(['logout']);
const router = useRouter();
const route = useRoute();

function navigate(item: any) {
  if (item.path) router.push(item.path);
}

function isActive(item: any) {
  return item.path === route.path;
}

function logout() {
  emit('logout');
}
</script>

<template>
  <aside class="text-white bg-gray-600 flex flex-col h-screen w-12 transition-all duration-300 ease-in-out justify-between">
    <!-- 顶部头像区域 -->
    <div class="pb-2 pt-6 flex items-center justify-center">
      <img src="" class="border border-white/20 rounded-full h-8 w-8">
    </div>
    <!-- Menu -->
    <nav class="py-4 flex-1">
      <ul class="space-y-2">
        <li
          v-for="item in menu"
          :key="item.name"
          :title="item.title"
          class="mx2 py-2 rounded-md flex-juster-center cursor-pointer transition-all duration-300 hover:bg-gray-700"
          :class="[
            isActive(item) ? 'bg-gray-700 shadow-inset ring-1 ring-white/10' : '',
          ]" @click="navigate(item)"
        >
          <component
            :is="item.icon" class="h-5 w-5"
            :class="isActive(item) ? 'text-white' : 'text-gray-400 group-hover:text-white transition-colors'"
          />
        </li>
      </ul>
    </nav>

    <!-- Logout -->
    <button
      class="border-t border-white/10 flex-juster-center h-16 transition-colors hover:bg-gray-700"
      title="Logout"
      @click="logout"
    >
      <LogOut class="h-5 w-5" />
    </button>
  </aside>
</template>
