<template>
  <aside class="w-16 bg-gray-600 text-white h-screen flex flex-col justify-between transition-all duration-300 ease-in-out">
    <!-- 顶部头像区域 -->
    <div class="flex justify-center items-center pt6 pb2">
      <img src="" class="w-8 h-8 rounded-full border border-white/20" />
    </div>
    <!-- Menu -->
    <nav class="flex-1 py-4">
      <ul class="space-y-2">
        <li
          v-for="item in menu"
          :key="item.name"
          @click="navigate(item)"
          :title="item.title"
          :class="[
            'cursor-pointer flex-juster-center py3 hover:bg-gray-700 transition-all duration-300 rounded-md mx2',
            isActive(item) ? 'bg-gray-700 shadow-inset ring-1 ring-white/10' : ''
          ]"
        >
          <component :is="item.icon" class="w-5 h-5"
            :class="isActive(item) ? 'text-white' : 'text-gray-400 group-hover:text-white transition-colors'"
          />
        </li>
      </ul>
    </nav>

    <!-- Logout -->
    <button
      class="h-16 flex-juster-center border-t border-white/10 hover:bg-gray-700 transition-colors"
      @click="logout"
      title="Logout"
    >
      <LogOut class="w-5 h-5" />
    </button>
  </aside>
</template>

<script setup lang="ts">
import { LogOut } from 'lucide-vue-next';

const router = useRouter();
const route = useRoute();

const { menu } = defineProps<{
  menu: Array<{
    name: string;
    title: string;
    icon: any;
    path: string;
  }>;
}>();

const emit = defineEmits(['logout']);

const navigate = (item: any) => {
  if (item.path) router.push(item.path);
};

const isActive = (item: any) => {
  return item.path === route.path;
};

const logout = () => {
  emit('logout');
};
</script>
