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
        class="fixed inset-0 bg-black/30 z-[1001]"
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
        class="fixed bottom-16 left-1/2 -translate-x-1/2 bg-[light-dark(white,#1f2937)] rounded-xl shadow-[0_8px_32px_rgba(0,0,0,0.2)] z-[1002] overflow-hidden flex gap-2 p-2"
      >
        <div
          v-for="submenuItem in menu.find(item => item.name === showSubmenu)?.submenu"
          :key="submenuItem.name"
          :title="submenuItem.title"
          class="p-4 cursor-pointer transition-colors duration-200 flex justify-center items-center rounded-lg min-w-12 min-h-12" :class="[
            isSubmenuActive(submenuItem)
              ? 'bg-[var(--color-primary)] text-white'
              : 'hover:bg-[light-dark(#f3f4f6,#374151)] text-[light-dark(#6b7280,#d1d5db)]',
          ]"
          @click="navigateSubmenu(submenuItem)"
        >
          <component
            :is="submenuItem.icon"
            class="w-6 h-6" :class="[
              isSubmenuActive(submenuItem) ? 'text-white' : '',
            ]"
          />
        </div>
      </div>
    </Transition>

    <!-- 底部导航 -->
    <nav class="fixed bottom-0 left-0 right-0 h-12 bg-[light-dark(#f3f4f6,#1f2937)] flex items-center justify-center shadow-[0_-1px_3px_0_rgba(0,0,0,0.1),0_-1px_2px_-1px_rgba(0,0,0,0.1)] border-t border-[light-dark(#e5e7eb,#374151)] z-[1000]">
      <ul class="flex w-full justify-around items-center list-none m-0 p-0">
        <li
          v-for="item in menu"
          :key="item.name"
          :title="item.title"
          class="flex flex-col items-center justify-center py-1 px-2 rounded-md cursor-pointer transition-all duration-300 ease-in-out" :class="[
            isActive(item)
              ? 'bg-[light-dark(#dbeafe,rgba(59,130,246,0.1))] shadow-[inset_0_0_0_1px_var(--color-primary)]'
              : 'hover:bg-[light-dark(#e5e7eb,#374151)]',
          ]"
          @click="navigate(item)"
        >
          <component
            :is="item.icon"
            class="w-5 h-5" :class="[
              isActive(item)
                ? 'text-[var(--color-primary)]'
                : 'text-[light-dark(#6b7280,#9ca3af)]',
            ]"
          />
        </li>
      </ul>
    </nav>
  </div>
</template>
