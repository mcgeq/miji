<script setup lang="ts">
const { menu } = defineProps<{
  menu: Array<{
    name: string;
    title: string;
    icon: any;
    path: string;
  }>;
}>();
const router = useRouter();
const route = useRoute();

function navigate(item: any) {
  if (item.path) router.push(item.path);
}

function isActive(item: any) {
  return item.path === route.path;
}
</script>

<template>
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
</template>

<style scoped lang="postcss">
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
  z-index: 50;
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
