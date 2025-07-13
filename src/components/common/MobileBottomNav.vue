<template>
  <nav class="fixed bottom-0 left-0 right-0 h-12 bg-gray-600 text-white shadow-lg rounded-md md:hidden">
    <ul class="flex justify-around h-full items-center">
      <li
        v-for="item in menu"
        :key="item.name"
        @click="navigate(item)"
        :title="item.title"
        :class="[
          'cursor-pointer flex flex-col items-center py-2 px-2 rounded-md transition-all duration-300 ease-in-out',
          isActive(item) ? 'bg-gray-700 shadow-inset ring-1 ring-white/10' : 'hover:bg-gray-700'
        ]"
      >
        <component
          :is="item.icon"
          class="w-5 h-5"
          :class="isActive(item) ? 'text-white' : 'text-gray-400 group-hover:text-white transition-colors'"
        />
      </li>
    </ul>
  </nav>
</template>

<script setup lang="ts">
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

const navigate = (item: any) => {
  if (item.path) router.push(item.path);
};

const isActive = (item: any) => {
  return item.path === route.path;
};
</script>

<style scoped>
/* You can add custom styles here if needed, but Tailwind generally handles most styling. */
</style>
