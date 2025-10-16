<script setup lang="ts">
import { LogOut } from 'lucide-vue-next';

const { menu } = defineProps<{ menu: Array<{ name: string; title: string; icon: any; path: string }> }>();

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
  <aside class="sidebar">
    <div class="sidebar-top">
      <img src="" alt="avatar" class="avatar">
    </div>

    <nav class="sidebar-menu">
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
  width: 3rem; /* 12 */
  height: 100vh; /* 覆盖整个视口高度 */
  position: fixed; /* 固定定位 */
  top: 0; /* 从顶部开始 */
  left: 0; /* 左侧固定 */
  z-index: 1000; /* 确保在最上层 */
  transition: all 0.3s ease-in-out;
  border-right: 1px solid var(--color-base-200);
  box-shadow: 2px 0 8px rgba(0, 0, 0, 0.05);
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
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 0.5rem 0;
  border-radius: 0.375rem; /* rounded-md */
  cursor: pointer;
  transition: all 0.3s;
}

.sidebar-menu li:hover {
  background-color: var(--color-base-200);
}

.sidebar-menu li.active {
  background-color: var(--color-primary-soft);
  box-shadow: inset 0 0 0 1px var(--color-primary);
}

.icon {
  width: 1.25rem;
  height: 1.25rem;
  color: var(--color-neutral);
}

.sidebar-menu li.active .icon {
  color: var(--color-primary);
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
