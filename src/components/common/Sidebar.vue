<script setup lang="ts">
import { BarChart3, LogOut } from 'lucide-vue-next';

interface MenuItem {
  name: string;
  title: string;
  icon: any;
  path: string;
  hasSubmenu?: boolean;
  submenu?: Array<{ name: string; title: string; path: string; icon?: any }>;
}

const { menu } = defineProps<{ menu: Array<MenuItem> }>();

const emit = defineEmits(['logout']);
const router = useRouter();
const route = useRoute();

// 展开的子菜单状态
const expandedMenus = ref<Set<string>>(new Set());

function navigate(item: MenuItem) {
  if (item.hasSubmenu) {
    // 切换子菜单展开状态
    if (expandedMenus.value.has(item.name)) {
      expandedMenus.value.delete(item.name);
    } else {
      expandedMenus.value.add(item.name);
    }
  } else if (item.path) {
    router.push(item.path);
  }
}

function navigateSubmenu(submenuItem: { name: string; title: string; path: string }) {
  router.push(submenuItem.path);
  // 导航后关闭所有子菜单
  expandedMenus.value.clear();
}

function isActive(item: MenuItem) {
  if (item.hasSubmenu && item.submenu) {
    // 如果是父菜单，检查子菜单是否有激活的
    return item.submenu.some(sub => sub.path === route.path);
  }
  return item.path === route.path;
}

function isSubmenuActive(submenuItem: { name: string; title: string; path: string }) {
  return submenuItem.path === route.path;
}

function isExpanded(itemName: string) {
  return expandedMenus.value.has(itemName);
}

function logout() {
  emit('logout');
}

// 点击外部关闭子菜单
function handleClickOutside(event: Event) {
  const target = event.target as Element;
  if (!target.closest('.sidebar')) {
    expandedMenus.value.clear();
  }
}

// 初始化时展开包含当前路由的菜单
onMounted(() => {
  menu.forEach(item => {
    if (item.hasSubmenu && item.submenu) {
      const hasActiveSubmenu = item.submenu.some(sub => sub.path === route.path);
      if (hasActiveSubmenu) {
        expandedMenus.value.add(item.name);
      }
    }
  });

  // 添加全局点击事件监听
  document.addEventListener('click', handleClickOutside);
});

onUnmounted(() => {
  // 清理事件监听
  document.removeEventListener('click', handleClickOutside);
});
</script>

<template>
  <aside class="w-12 h-screen fixed top-0 left-0 z-[1000] flex flex-col justify-between bg-[var(--color-base-300)] text-[var(--color-base-content)] border-r border-[var(--color-base-200)] shadow-[2px_0_8px_rgba(0,0,0,0.05)] transition-all duration-300 ease-in-out overflow-visible">
    <!-- 顶部头像 -->
    <div class="pt-6 pb-2 flex justify-center">
      <img src="" alt="avatar" class="w-8 h-8 rounded-full border border-[var(--color-neutral)]">
    </div>

    <!-- 菜单区域 -->
    <nav class="flex-1 py-4">
      <ul class="list-none p-0 m-0">
        <li
          v-for="item in menu"
          :key="item.name"
          class="relative my-1"
        >
          <!-- 菜单项 -->
          <div
            class="flex justify-center items-center p-3 rounded-md cursor-pointer transition-all duration-300 relative hover:bg-[var(--color-base-100)]" :class="[
              isActive(item) && 'bg-[var(--color-primary)] text-[var(--color-primary-content)]',
            ]"
            :title="item.title"
            @click="navigate(item)"
          >
            <component
              :is="item.icon"
              class="w-5 h-5" :class="[
                isActive(item) ? 'text-[var(--color-base-content)]' : 'text-[var(--color-neutral)]',
              ]"
            />
          </div>

          <!-- 子菜单 -->
          <Transition
            enter-active-class="transition-all duration-200 ease-out"
            enter-from-class="opacity-0 -translate-x-2"
            enter-to-class="opacity-100 translate-x-0"
            leave-active-class="transition-all duration-200 ease-in"
            leave-from-class="opacity-100 translate-x-0"
            leave-to-class="opacity-0 -translate-x-2"
          >
            <ul
              v-if="item.hasSubmenu && isExpanded(item.name)"
              class="absolute left-full top-0 w-12 bg-[var(--color-base-200)] rounded-lg shadow-[0_4px_12px_rgba(0,0,0,0.15)] z-[1001] overflow-hidden"
            >
              <li
                v-for="submenuItem in item.submenu"
                :key="submenuItem.name"
                class="p-3 cursor-pointer transition-colors duration-200 border-b border-[var(--color-base-300)] flex justify-center items-center last:border-b-0 hover:bg-[var(--color-base-100)]" :class="[
                  isSubmenuActive(submenuItem) && 'bg-[var(--color-primary)] text-[var(--color-primary-content)]',
                ]"
                :title="submenuItem.title"
                @click="navigateSubmenu(submenuItem)"
              >
                <component
                  :is="submenuItem.icon || BarChart3"
                  class="w-4 h-4" :class="[
                    isSubmenuActive(submenuItem) ? 'text-[var(--color-primary-content)]' : 'text-[var(--color-neutral)]',
                  ]"
                />
              </li>
            </ul>
          </Transition>
        </li>
      </ul>
    </nav>

    <!-- 登出按钮 -->
    <button
      class="h-16 border-t border-[var(--color-base-200)] bg-transparent flex justify-center items-center cursor-pointer transition-all duration-300 ease-in-out text-[var(--color-base-content)] hover:text-[var(--color-error-content)] hover:scale-105 active:scale-95"
      title="Logout"
      @click="logout"
    >
      <LogOut class="w-5 h-5" />
    </button>
  </aside>
</template>
