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
  <div class="mobile-nav-container">
    <!-- 背景遮罩 -->
    <div
      v-if="showSubmenu"
      class="submenu-overlay"
      @click="closeSubmenu"
    />

    <!-- 子菜单弹窗 -->
    <div
      v-if="showSubmenu"
      class="mobile-submenu"
    >
      <div
        v-for="submenuItem in menu.find(item => item.name === showSubmenu)?.submenu"
        :key="submenuItem.name"
        :class="{ active: isSubmenuActive(submenuItem) }"
        :title="submenuItem.title"
        class="submenu-item"
        @click="navigateSubmenu(submenuItem)"
      >
        <component
          :is="submenuItem.icon"
          class="submenu-icon"
        />
      </div>
    </div>

    <!-- 底部导航 -->
    <nav class="mobile-nav">
      <ul>
        <li
          v-for="item in menu"
          :key="item.name"
          :title="item.title"
          :class="{ active: isActive(item) }"
          @click="navigate(item)"
        >
          <component :is="item.icon" class="icon" />
        </li>
      </ul>
    </nav>
  </div>
</template>

<style scoped lang="postcss">
.mobile-nav-container {
  position: relative;
}

/* 背景遮罩 */
.submenu-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.3);
  z-index: 1001;
}

/* 移动端子菜单弹窗 */
.mobile-submenu {
  position: fixed;
  bottom: 4rem; /* 在底部导航上方 */
  left: 50%;
  transform: translateX(-50%);
  background-color: var(--color-base-100);
  border-radius: 0.75rem;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
  z-index: 1002;
  overflow: hidden;
  animation: slideUp 0.3s ease-out;
  display: flex;
  gap: 0.5rem;
  padding: 0.5rem;
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateX(-50%) translateY(1rem);
  }
  to {
    opacity: 1;
    transform: translateX(-50%) translateY(0);
  }
}

.submenu-item {
  padding: 1rem;
  cursor: pointer;
  transition: background-color 0.2s;
  display: flex;
  justify-content: center;
  align-items: center;
  border-radius: 0.5rem;
  min-width: 3rem;
  min-height: 3rem;
}

.submenu-item:hover {
  background-color: var(--color-base-200);
}

.submenu-item.active {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
}

.submenu-icon {
  width: 1.5rem;
  height: 1.5rem;
  color: var(--color-neutral);
}

.submenu-item.active .submenu-icon {
  color: var(--color-primary-content);
}

/* 底部导航样式 */
.mobile-nav {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: 3rem;
  background-color: var(--color-base-300);
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: var(--shadow-lg);
  border-top: 1px solid var(--color-neutral);
  z-index: 1000;
}

.mobile-nav ul {
  display: flex;
  width: 100%;
  justify-content: space-around;
  align-items: center;
  list-style: none;
  margin: 0;
  padding: 0;
}

.mobile-nav li {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: all 0.3s ease-in-out;
}

.mobile-nav li:hover {
  background-color: var(--color-base-200);
}

.mobile-nav li.active {
  background-color: var(--color-primary-soft);
  box-shadow: inset 0 0 0 1px var(--color-primary);
}

.icon {
  width: 1.25rem;
  height: 1.25rem;
  color: var(--color-neutral);
}

.mobile-nav li.active .icon {
  color: var(--color-primary);
}
</style>
