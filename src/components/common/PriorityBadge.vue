<!--
  -----------------------------------------------------------------------------
  Copyright (C) 2025 mcge. All rights reserved.
  Author:         mcge
  Email:          <mcgeq@outlook.com>
  File:           PriorityBadge.svelte
  Description:    About Priority
  Create   Date:  2025-06-21 20:20:20
  Last Modified:  2025-06-21 20:20:20
  Modified   By:  mcge <mcgeq@outlook.com>
  -----------------------------------------------------------------------------
-->
<script setup lang="ts">
import { PrioritySchema } from '@/schema/common';
import type { Priority } from '@/schema/common';

const props = defineProps<{
  serialNum: string;
  priority: Priority;
  completed: boolean;
  onChangePriority: (serialNum: string, p: Priority) => void;
}>();

const emit = defineEmits<{
  (e: 'changePriority', serialNum: string, priority: Priority): void;
}>();

const priorities: Priority[] = PrioritySchema.options;

const showMenu = ref(false);
const { t } = useI18n();

const priorityKeyMap = {
  LOW: 'todos.priority.low',
  MEDIUM: 'todos.priority.medium',
  HIGH: 'todos.priority.high',
  URGENT: 'todos.priority.urgent',
} as const;

const gradientMap = {
  LOW: 'from-emerald-300 to-teal-200',
  MEDIUM: 'from-amber-300 to-orange-200',
  HIGH: 'from-rose-400 to-red-300',
  URGENT: 'from-purple-400 to-red-400',
} as const;

const textColorMap = {
  LOW: 'text-emerald-900',
  MEDIUM: 'text-amber-900',
  HIGH: 'text-red-800',
  URGENT: 'text-purple-800',
} as const;

const normalizedPriority = computed(
  () => props.priority.toUpperCase() as keyof typeof priorityKeyMap,
);

const priorityLabel = computed(() =>
  t(priorityKeyMap[normalizedPriority.value]),
);

const priorityClasses = computed(() => ({
  gradient: gradientMap[normalizedPriority.value],
  text: textColorMap[normalizedPriority.value],
}));

function selectPriority(serialNum: string, p: Priority) {
  showMenu.value = false;
  emit('changePriority', serialNum, p);
}
</script>

<template>
  <button
    class="animate-pulse-subtle text-xs font-semibold border border-white/30 rounded-full bg-opacity-90 flex h-5 w-5 shadow-[0_0_10px_rgba(0,0,0,0.15)] transition-all duration-300 ease-out items-center left-1 top-1 justify-center absolute backdrop-blur-md dark:shadow-[0_0_10px_rgba(255,255,255,0.15)] hover:shadow-lg hover:scale-125" :class="[
      `bg-gradient-to-br ${priorityClasses.gradient}`,
      priorityClasses.text,
    ]"
    :title="priorityLabel"
    :aria-label="priorityLabel"
    :disabled="completed"
    @click="showMenu = !showMenu"
  >
    <span class="drop-shadow-sm">{{ priorityLabel }}</span>
  </button>

  <div
    v-if="showMenu"
    class="p-1 border border-gray-200 rounded-lg bg-white w-10 shadow-md left-0 top-7 absolute z-50 backdrop-blur-md dark:border-neutral-700 dark:bg-neutral-800 dark:shadow-lg"
  >
    <button
      v-for="p in priorities"
      :key="p"
      class="text-[13px] tracking-wide font-medium px-2.5 py-1 rounded-md w-full block transition-colors duration-150 ease-in-out hover:bg-gray-100 active:scale-[0.98] dark:hover:bg-neutral-700" :class="[
        p === priority ? 'bg-gray-200 dark:bg-neutral-600 font-semibold text-black dark:text-white' : 'text-gray-800 dark:text-gray-100',
      ]"
      @click="selectPriority(serialNum, p)"
    >
      {{ t(priorityKeyMap[p.toUpperCase() as keyof typeof priorityKeyMap] || priorityKeyMap.LOW) }}
    </button>
  </div>
</template>

<style scoped>
.animate-pulse-subtle:hover {
  animation: pulse-subtle 2s ease-in-out infinite;
}

@keyframes pulse-subtle {
  0%, 100% {
    transform: scale(1);
    opacity: 1;
  }
  50% {
    transform: scale(1.1);
    opacity: 0.8;
  }
}
</style>
