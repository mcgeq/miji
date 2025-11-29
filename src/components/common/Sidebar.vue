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
      // 关闭其他所有子菜单，只展开当前的
      expandedMenus.value.clear();
      expandedMenus.value.add(item.name);
    }
  } else if (item.path) {
    // 点击一级菜单时关闭所有子菜单
    expandedMenus.value.clear();
    router.push(item.path);
  }
}

function navigateSubmenu(submenuItem: { name: string; title: string; path: string }, event: Event) {
  // 阻止事件冒泡，防止触发 handleClickOutside
  event.stopPropagation();
  router.push(submenuItem.path);
  // 导航后关闭子菜单
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
  // 检查点击是否在侧边栏或子菜单内
  if (!target.closest('aside') && !target.closest('.submenu-container')) {
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
  <aside class="w-12 h-screen fixed top-0 left-0 z-[1000] flex flex-col justify-between bg-gradient-to-b from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-950 text-gray-700 dark:text-gray-300 border-r border-gray-200 dark:border-gray-800 shadow-lg transition-all duration-300 ease-in-out overflow-visible backdrop-blur-sm">
    <!-- 顶部头像 -->
    <div class="pt-6 pb-2 flex justify-center">
      <img src="" alt="avatar" class="w-8 h-8 rounded-full border-2 border-gray-300 dark:border-gray-700 shadow-md hover:scale-110 transition-transform duration-200">
    </div>

    <!-- 菜单区域 -->
    <nav class="flex-1 py-4 px-1.5">
      <ul class="list-none p-0 m-0">
        <li
          v-for="item in menu"
          :key="item.name"
          class="relative my-1"
        >
          <!-- 菜单项 -->
          <div
            class="flex justify-center items-center p-2.5 rounded-lg cursor-pointer transition-all duration-200 relative group" :class="[
              isActive(item)
                ? 'bg-blue-500 dark:bg-blue-600 shadow-lg shadow-blue-500/30 dark:shadow-blue-600/30'
                : 'hover:bg-gray-200 dark:hover:bg-gray-800',
            ]"
            :title="item.title"
            @click="navigate(item)"
          >
            <!-- 选中指示器 -->
            <div
              v-if="isActive(item)"
              class="absolute -left-1 top-1/2 -translate-y-1/2 w-1 h-6 bg-blue-500 dark:bg-blue-400 rounded-r-full"
            />
            <component
              :is="item.icon"
              class="w-5 h-5 transition-all duration-200" :class="[
                isActive(item)
                  ? 'text-white'
                  : 'text-gray-600 dark:text-gray-400 group-hover:text-gray-900 dark:group-hover:text-gray-200 group-hover:scale-110',
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
              class="submenu-container absolute left-full top-1/2 -translate-y-1/2 ml-2 bg-white dark:bg-gray-800 rounded-xl shadow-xl border border-gray-200 dark:border-gray-700 z-[1001] overflow-hidden backdrop-blur-sm flex flex-col p-1.5"
            >
              <template
                v-for="(submenuItem, index) in item.submenu"
                :key="submenuItem.name"
              >
                <li
                  class="w-9 h-9 flex justify-center items-center rounded-lg cursor-pointer transition-all duration-200 group" :class="[
                    isSubmenuActive(submenuItem)
                      ? 'bg-blue-500 dark:bg-blue-600 shadow-md shadow-blue-500/30'
                      : 'hover:bg-gray-100 dark:hover:bg-gray-700',
                  ]"
                  :title="submenuItem.title"
                  @click="navigateSubmenu(submenuItem, $event)"
                >
                  <component
                    :is="submenuItem.icon || BarChart3"
                    class="w-4 h-4 transition-all duration-200" :class="[
                      isSubmenuActive(submenuItem)
                        ? 'text-white'
                        : 'text-gray-600 dark:text-gray-400 group-hover:text-gray-900 dark:group-hover:text-gray-200 group-hover:scale-110',
                    ]"
                  />
                </li>
                <!-- 分隔线 -->
                <div
                  v-if="index < item.submenu!.length - 1"
                  class="h-px w-4/5 bg-gray-200 dark:bg-gray-700 mx-auto my-1"
                />
              </template>
            </ul>
          </Transition>
        </li>
      </ul>
    </nav>

    <!-- 登出按钮 -->
    <button
      class="h-16 border-t border-gray-200 dark:border-gray-800 bg-transparent flex justify-center items-center cursor-pointer transition-all duration-200 group"
      title="Logout"
      @click="logout"
    >
      <LogOut class="w-5 h-5 text-gray-500 dark:text-gray-400 group-hover:text-red-500 dark:group-hover:text-red-400 group-hover:scale-110 group-active:scale-95 transition-all duration-200" />
    </button>
  </aside>
</template>
