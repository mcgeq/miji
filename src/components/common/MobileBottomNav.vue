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
  <nav class="text-white rounded-md bg-gray-600 h-12 shadow-lg bottom-0 left-0 right-0 fixed md:hidden">
    <ul class="flex h-full items-center justify-around">
      <li
        v-for="item in menu"
        :key="item.name"
        :title="item.title"
        class="px-2 py-2 rounded-md flex flex-col cursor-pointer transition-all duration-300 ease-in-out items-center"
        :class="[
          isActive(item) ? 'bg-gray-700 shadow-inset ring-1 ring-white/10' : 'hover:bg-gray-700',
        ]" @click="navigate(item)"
      >
        <component
          :is="item.icon"
          class="h-5 w-5"
          :class="isActive(item) ? 'text-white' : 'text-gray-400 group-hover:text-white transition-colors'"
        />
      </li>
    </ul>
  </nav>
</template>

<style scoped>
/* You can add custom styles here if needed, but Tailwind generally handles most styling. */
</style>
