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
  <aside class="sidebar">
    <div class="sidebar-top">
      <img src="" alt="avatar" class="avatar">
    </div>

    <nav class="sidebar-menu">
      <ul>
        <li
          v-for="item in menu"
          :key="item.name"
          :class="{ 'active': isActive(item), 'has-submenu': item.hasSubmenu }"
        >
          <div
            class="menu-item"
            :title="item.title"
            @click="navigate(item)"
          >
            <component :is="item.icon" class="icon" />
          </div>

          <!-- 子菜单 -->
          <ul v-if="item.hasSubmenu && isExpanded(item.name)" class="submenu">
            <li
              v-for="submenuItem in item.submenu"
              :key="submenuItem.name"
              :class="{ active: isSubmenuActive(submenuItem) }"
              :title="submenuItem.title"
              @click="navigateSubmenu(submenuItem)"
            >
              <component
                :is="submenuItem.icon || BarChart3"
                class="submenu-icon"
              />
            </li>
          </ul>
        </li>
      </ul>
    </nav>

    <button class="logout-btn" title="Logout" @click="logout">
      <LogOut class="icon" />
    </button>
  </aside>
</template>

<style scoped lang="postcss">
.sidebar {
  background-color: var(--color-base-300);
  color: var(--color-base-content);
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  width: 3rem; /* 固定宽度，不变化 */
  height: 100vh;
  position: fixed;
  top: 0;
  left: 0;
  z-index: 1000;
  transition: all 0.3s ease-in-out;
  border-right: 1px solid var(--color-base-200);
  box-shadow: 2px 0 8px rgba(0, 0, 0, 0.05);
  overflow: visible; /* 允许子菜单溢出 */
}

.sidebar-top {
  padding: 1.5rem 0 0.5rem 0;
  display: flex;
  justify-content: center;
}

.avatar {
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  border: 1px solid var(--color-neutral);
}

.sidebar-menu {
  flex: 1;
  padding: 1rem 0;
}

.sidebar-menu ul {
  list-style: none;
  padding: 0;
  margin: 0;
}

.sidebar-menu li {
  position: relative;
  margin: 0.25rem 0;
}

.menu-item {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 0.75rem;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: all 0.3s;
  position: relative;
}

.menu-item:hover {
  background-color: var(--color-base-100);
}

.sidebar-menu li.active .menu-item {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
}

/* 子菜单样式 */
.submenu {
  position: absolute;
  left: 100%;
  top: 0;
  background-color: var(--color-base-200);
  border-radius: 0.5rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  width: 3rem; /* 固定宽度，与主侧边栏一致 */
  z-index: 1001;
  overflow: hidden;
  animation: slideIn 0.2s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateX(-0.5rem);
  }
  to {
    opacity: 1;
    transform: translateX(0);
  }
}

.submenu li {
  margin: 0;
  padding: 0.75rem;
  cursor: pointer;
  transition: background-color 0.2s;
  border-bottom: 1px solid var(--color-base-300);
  display: flex;
  justify-content: center;
  align-items: center;
}

.submenu li:last-child {
  border-bottom: none;
}

.submenu li:hover {
  background-color: var(--color-base-100);
}

.submenu li.active {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
}

.submenu-icon {
  width: 1rem;
  height: 1rem;
  color: var(--color-neutral);
}

.submenu li.active .submenu-icon {
  color: var(--color-primary-content);
}

.icon {
  width: 1.25rem;
  height: 1.25rem;
  color: var(--color-neutral);
}

.sidebar-menu li.active .icon {
  color: var(--color-base-content);
}

.logout-btn {
  height: 4rem;
  border-top: 1px solid var(--color-base-200);
  background: none;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;
  transition: background-color 0.3s ease, transform 0.1s ease;
  color: var(--color-base-content);
}

.logout-btn:hover {
  color: var(--color-error-content);
  transform: scale(1.05);
}
.logout-btn:active {
  transform: scale(0.95);
}
</style>
