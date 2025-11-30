<script setup lang="ts">
const props = defineProps<{ completed: boolean }>();
const emit = defineEmits(['toggle']);
const completed = computed(() => props.completed);
</script>

<template>
  <button
    type="button"
    class="flex items-center justify-center border-none bg-transparent cursor-pointer p-1 rounded-full transition-all duration-200 outline-none hover:not-disabled:scale-110 focus:not-disabled:scale-110 disabled:cursor-not-allowed disabled:opacity-60"
    :aria-pressed="completed"
    :disabled="completed"
    @click="emit('toggle')"
  >
    <LucideCheckCircle v-if="completed" class="w-5 h-5 transition-all duration-200 text-success dark:text-success" />
    <LucideCircle v-else class="w-5 h-5 transition-all duration-200 text-neutral dark:text-neutral" />
  </button>
</template>
