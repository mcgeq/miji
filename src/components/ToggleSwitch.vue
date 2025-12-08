<script setup lang="ts">
  defineProps<{
    modelValue: boolean;
  }>();

  defineEmits<{
    'update:modelValue': [value: boolean];
  }>();
</script>

<template>
  <label class="inline-flex cursor-pointer items-center relative">
    <input
      :checked="modelValue"
      type="checkbox"
      class="sr-only"
      @change="$emit('update:modelValue', ($event.target as HTMLInputElement).checked)"
    />
    <div
      class="w-12 h-6 rounded-full transition-colors relative"
      :class="modelValue ? 'bg-blue-600' : 'bg-gray-300 dark:bg-gray-600'"
    >
      <div
        class="absolute w-5 h-5 bg-white rounded-full top-0.5 transition-transform"
        :class="modelValue ? 'translate-x-6' : 'translate-x-0.5'"
      />
    </div>
  </label>
</template>
