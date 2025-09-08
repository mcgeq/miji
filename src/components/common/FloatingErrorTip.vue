<!-- src/components/FloatingErrorTip.vue -->
<script setup lang="ts">
defineProps<{
  message?: string;
  visible?: boolean;
}>();
</script>

<template>
  <div
    v-if="visible && message"
    class="text-xs text-red-500 pointer-events-none select-none whitespace-nowrap transform right-2 top-1/2 absolute z-10 -translate-y-1/2"
  >
    {{ message }}
  </div>
</template>
