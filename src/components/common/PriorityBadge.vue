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
<template>
  <button
    :class="[
      'absolute left-1 top-1 w-5 h-5 rounded-full flex items-center justify-center text-xs font-semibold transition-all duration-300 ease-out hover:scale-125 hover:shadow-lg bg-opacity-90 backdrop-blur-md border border-white/30 shadow-[0_0_10px_rgba(0,0,0,0.15)] dark:shadow-[0_0_10px_rgba(255,255,255,0.15)] animate-pulse-subtle',
      `bg-gradient-to-br ${priorityClasses.gradient}`,
      priorityClasses.text
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
    class="absolute top-7 left-0 z-50 w-10 bg-white dark:bg-neutral-800 rounded-lg border border-gray-200 dark:border-neutral-700 shadow-md dark:shadow-lg p-1 backdrop-blur-md"
  >
    <button
      v-for="p in priorities"
      :key="p"
      @click="selectPriority(serialNum, p)"
      :class="[
        'block w-full px-2.5 py-1 text-[13px] font-medium tracking-wide rounded-md transition-colors duration-150 ease-in-out',
        'hover:bg-gray-100 dark:hover:bg-neutral-700 active:scale-[0.98]',
        p === priority ? 'bg-gray-200 dark:bg-neutral-600 font-semibold text-black dark:text-white' : 'text-gray-800 dark:text-gray-100'
      ]"
    >
      {{ t(priorityKeyMap[p.toUpperCase() as keyof typeof priorityKeyMap] || priorityKeyMap.LOW) }}
    </button>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { Priority, PrioritySchema } from '@/schema/common';

const priorities: Priority[] = PrioritySchema.options;

const emit = defineEmits<{
  (e: 'changePriority', serialNum: string, priority: Priority): void;
}>();

const props = defineProps<{
  serialNum: string;
  priority: Priority;
  completed: boolean;
  onChangePriority: (serialNum: string, p: Priority) => void;
}>();

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
