<script setup lang="ts">
interface MenuItem {
  name: string;
  title: string;
  icon: any;
  path: string;
  hasSubmenu?: boolean;
  submenu?: Array<{ name: string; title: string; path: string; icon?: any }>;
}

const { menu } = defineProps<{
  menu: Array<MenuItem>;
}>();

const router = useRouter();
const route = useRoute();

// 显示子菜单的状态
const showSubmenu = ref<string | null>(null);

function navigate(item: MenuItem) {
  if (item.hasSubmenu) {
    // 切换子菜单显示状态
    showSubmenu.value = showSubmenu.value === item.name ? null : item.name;
  } else if (item.path) {
    router.push(item.path);
    showSubmenu.value = null; // 导航后关闭子菜单
  }
}

function navigateSubmenu(submenuItem: { name: string; title: string; path: string; icon?: any }) {
  router.push(submenuItem.path);
  showSubmenu.value = null; // 导航后关闭子菜单
}

function isActive(item: MenuItem) {
  if (item.hasSubmenu && item.submenu) {
    // 如果是父菜单，检查子菜单是否有激活的
    return item.submenu.some(sub => sub.path === route.path);
  }
  return item.path === route.path;
}

function isSubmenuActive(submenuItem: { name: string; title: string; path: string; icon?: any }) {
  return submenuItem.path === route.path;
}

// 点击外部关闭子菜单
function closeSubmenu() {
  showSubmenu.value = null;
}
</script>

<template>
  <div class="relative">
    <!-- 背景遮罩 -->
    <Transition
      enter-active-class="transition-opacity duration-200 ease-out"
      leave-active-class="transition-opacity duration-150 ease-in"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="showSubmenu"
        class="fixed inset-0 bg-black/40 backdrop-blur-sm z-[1001]"
        @click="closeSubmenu"
      />
    </Transition>

    <!-- 子菜单弹窗 -->
    <Transition
      enter-active-class="transition-all duration-300 ease-out"
      leave-active-class="transition-all duration-200 ease-in"
      enter-from-class="opacity-0 translate-y-4"
      enter-to-class="opacity-100 translate-y-0"
      leave-from-class="opacity-100 translate-y-0"
      leave-to-class="opacity-0 translate-y-4"
    >
      <div
        v-if="showSubmenu"
        class="fixed bottom-16 left-1/2 -translate-x-1/2 bg-white dark:bg-gray-800 rounded-2xl shadow-2xl border border-gray-200 dark:border-gray-700 z-[1002] overflow-hidden flex gap-2 p-3 backdrop-blur-md"
      >
        <div
          v-for="submenuItem in menu.find(item => item.name === showSubmenu)?.submenu"
          :key="submenuItem.name"
          :title="submenuItem.title"
          class="p-4 cursor-pointer transition-all duration-200 flex justify-center items-center rounded-xl min-w-12 min-h-12 group" :class="[
            isSubmenuActive(submenuItem)
              ? 'bg-blue-500 dark:bg-blue-600 shadow-lg shadow-blue-500/30'
              : 'hover:bg-gray-100 dark:hover:bg-gray-700',
          ]"
          @click="navigateSubmenu(submenuItem)"
        >
          <component
            :is="submenuItem.icon"
            class="w-6 h-6 transition-all duration-200" :class="[
              isSubmenuActive(submenuItem)
                ? 'text-white'
                : 'text-gray-600 dark:text-gray-400 group-hover:text-gray-900 dark:group-hover:text-gray-200 group-hover:scale-110',
            ]"
          />
        </div>
      </div>
    </Transition>

    <!-- 底部导航 -->
    <nav class="fixed bottom-0 left-0 right-0 h-14 bg-white/80 dark:bg-gray-900/80 backdrop-blur-lg flex items-center justify-center shadow-[0_-4px_16px_rgba(0,0,0,0.1)] border-t border-gray-200 dark:border-gray-800 z-[1000]">
      <ul class="flex w-full justify-around items-center list-none m-0 p-0 px-2">
        <li
          v-for="item in menu"
          :key="item.name"
          :title="item.title"
          class="flex flex-col items-center justify-center py-2 px-3 rounded-xl cursor-pointer transition-all duration-200 relative group" :class="[
            isActive(item)
              ? 'bg-blue-50 dark:bg-blue-900/30'
              : 'hover:bg-gray-100 dark:hover:bg-gray-800',
          ]"
          @click="navigate(item)"
        >
          <!-- 选中指示器 -->
          <div
            v-if="isActive(item)"
            class="absolute -top-0.5 left-1/2 -translate-x-1/2 w-8 h-1 bg-blue-500 dark:bg-blue-400 rounded-b-full"
          />
          <component
            :is="item.icon"
            class="w-6 h-6 transition-all duration-200" :class="[
              isActive(item)
                ? 'text-blue-600 dark:text-blue-400 scale-110'
                : 'text-gray-600 dark:text-gray-400 group-hover:text-gray-900 dark:group-hover:text-gray-200 group-hover:scale-110',
            ]"
          />
          <!-- 激活动画点 -->
          <div
            v-if="isActive(item)"
            class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-10 h-10 bg-blue-500/10 dark:bg-blue-400/10 rounded-full animate-ping"
          />
        </li>
      </ul>
    </nav>
  </div>
</template>
